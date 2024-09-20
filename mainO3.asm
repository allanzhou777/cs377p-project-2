@ -----high level overview-----
@ Similar to the -o1 code, two parameters are passed into the -o3 code
@ The first is 'input', a 64-bit address to an array, which is passed in register rdi
@ The second is 'length', a 32-bit integer representing the number of elements in the 
@ array, which is passed in register esi. 

@ Similar to the -O1 code, we first start by determining if the length of the array
@ is valid. If the length is <= 0, we jump to L7. From L7, we XOR the contents
@ of register eax with itself to make 0, and then return.

@ If the length of the array is a positive integer, we calculate the length - 1 using 'length'
@ in the rsi register. Then, we compare 'length - 1' to 3, to see if vector addition can be applied.
@ If 'length' <= 4, we jump to L8 and add the items in this array one at a time. From L8, we jump to L3,
@ which will be used in the future again for remaining elements that aren't summed using
@ vector-compatible registers. After summing all small array items, the sum is returned in L1.

@ If the length of the array is a positive integer, and 'length' > 4,
@ then we use vector-compatible registers, such as xmm0 or xmm1, to do calculations 
@ more efficiently. We initialize xmm0 to store the vector sums, and integer divide length by 4
@ to determine the number of times we'll shift the vector block over the array. We then calculate the address of the 
@ last block by multiplying (# of vector blocks)(16), since 1 vector block = 4 integers = 16 bytes. This address
@ will be used to determine when to stop our vector summing block. 

@ In this next section L4, we begin our vector summing. We load 4 integers at a time 
@ into xmm2, shift the vector pointer 16 bytes, and then sum these 4 elements.
@ We then determine if we've reached the end of the array by comparing our current 
@ address with the address of the last block we calculated earlier and setting necessary flags. 
@ If we haven't reached the end, we repeat this process and sum up the next 4 integers, continuing until we reach
@ the end address we computed earlier. This vector of 4 items is summed in the following way: 

@ Initially
@ xmm0[0] = arr[0] + arr[4] + ...
@ xmm0[1] = arr[1] + arr[5] + ...
@ xmm0[2] = arr[2] + arr[6] + ...
@ xmm0[3] = arr[3] + arr[7] + ...

@ Then, we take the top two numbers xmm0[2] and xmm0[3], shift them down 8 bytes and add to get this sum
@ xmm0[0] = arr[0] + arr[2] + arr[4] + arr[6] + ...
@ xmm0[1] = arr[1] + arr[3] + arr[5] + arr[7] + ...

@ Then, we take the top number xmm0[1], shift it down by 4 bytes, and get this desired sum
@ xmm0[0] = arr[0] + arr[1] + arr[2] + arr[3] + ...

@ After we get all possible vector sums, we may have 1, 2, 3, or 4 extra array elements we didn't sum
@ using a vector. The remaining code in L3 accounts for this by adding the next single element, incrementing the
@ pointer, and continuing to add the next single element if the pointer hasn't reached the end of the array.
@ Upon reaching the end of the array (after summing up the additional 1, 2, 3, or 4 remaining elements),
@ the sum is returned in eax.

@ -----line by line comments-----
testl   %esi, %esi     ; same as -o1 code, this does an operation on length & length to set the flags
jle     .L7            ; if the flags indicate that length <= 0, then jump to L7

leal    -1(%rsi), %eax ; compute length - 1 using length (rsi) and store result in eax
cmpl    $3, %eax       ; compare length - 1 with 3 (aka comparing length with 4)
jbe     .L8            ; if length <= 4, then we jump to L8 to process the small array

movl    %esi, %edx     ; copy 'length' from esi to edx for future computations
movq    %rdi, %rax     ; move the base address of the array from rdi to rax

pxor    %xmm0, %xmm0   ; zero out the xmm0 register by XORing with itself. This will be our sum variable 

shrl    $2, %edx       ; do a right shift of two bits (i.e. divide by 4) on 'length', which calculates the number of times we'll iterate over array using a vector (a vector block can store 4 integers at once)
salq    $4, %rdx       ; do a left shift of 4 bits (i.e. multiply by 16). This converts the number of vector blocks into bytes of offset. 1 vector block -> 4 integers -> 16 bytes
addq    %rdi, %rdx     ; get the address of the last block by adding byte offset to array start address, which leaves us with the address of the last element

.L4:
movdqu  (%rax), %xmm2  ; load 4 32-bit integers from the address rax into the vector compatible register xmm2
addq    $16, %rax      ; add 16 bytes to address of rax, which now points to next block of 4 integers
paddd   %xmm2, %xmm0   ; do a packed vector addition, adding the 4 integers in xmm2 to the corresponding integers in xmm0
cmpq    %rdx, %rax     ; compare the current address in rax with rdxthe address of the last block rdx, setting the flags. 
jne     .L4            ; if the addresses aren't equal, jump to L4 and continue for the next 4 integers. 

movdqa  %xmm0, %xmm1   ; move the vector compatible sum in xmm0 to xmm1
movl    %esi, %edx     ; copy 'length' back into edx, which will be used for future computations
psrldq  $8, %xmm1      ; shift xmm1 right by 8 bytes (or 64 bits), moving the 2 integers occuping the higher parts of xmm0 to the lower part of xmm1. This writes over the 2 integers in the lower 8 bytes. The goal here is to combine the 4 separate sums into 2 sums, then 1 final sum
andl    $-4, %edx      ; align edx to the nearest multiple of 4 by making the last 2 bits 0. 
paddd   %xmm1, %xmm0   ; add xmm1 and xmm0, making the 4 vector sum a 2 vector sum

movdqa  %xmm0, %xmm1   ; repeat the same process converting 2 vector sum to a 1 vector sum. First move xmm0 to xmm1
psrldq  $4, %xmm1      ; shift xmm1 right by 4 bytes (sizeof(int)), writing over the element in the lowest 4 bytes
paddd   %xmm1, %xmm0   ; add xmm1 and xmm0, making the 2 vector sum a 1 vector sum

movd    %xmm0, %eax    ; move xmm0 to eax

testb   $3, %sil       ; determine if all elements have been added by doing 3 & sil (esi mod 4).
je      .L11           ; if the mod is equal, then all elements have been processed and jump to L11. Otherwise, continue below

.L3:
movslq  %edx, %rcx     ; convert edx from 32 bit to 64 bit and store this value in rcx
addl    (%rdi,%rcx,4), %eax ; add input[edx] to sum variable in eax
leal    1(%rdx), %ecx  ; increment edx by 1, and store this variable in ecx
cmpl    %ecx, %esi     ; see if we've reached 'length'
jle     .L1            ; if we've gone through the entire length of the array, jump to L1
movslq  %ecx, %rcx     ; convert ecx from 32 bit to 64 bit, storing the result in rcx. 
addl    (%rdi,%rcx,4), %eax ; add the next item to eax to eax
leal    2(%rdx), %ecx  ; increment rdx by 2, storing the result in ecx
cmpl    %ecx, %esi     ; compare ecx to esi
jle     .L1            ; if we've processed all items, jump to L1
movslq  %ecx, %rcx     ; same as above, convert from 32 bit to 64 bit
addl    $3, %edx       ; increment edx by 3
addl    (%rdi,%rcx,4), %eax ; add remaining item
cmpl    %edx, %esi     ; compare indices of edx and esi
jle     .L1            ; if we've processed all items, jump to L1

movslq  %edx, %rdx     ; convert the final item from 32 bit to 64 bit
addl    (%rdi,%rdx,4), %eax ; add the final item to eax
ret                    ; return the answer, stored in eax. 

.L7:
xorl    %eax, %eax     ; if length <= 0, then set eax to 0

.L1:
ret                    ; return the sum of 0 (after adding remaining items)

.L11:
ret                    ; return the sum, since no more elements need processing from above (after doing all vector sums)

.L8:
xorl    %edx, %edx     ; make edx 0 in order to find sum of small arrays
xorl    %eax, %eax     ; zero out the sum variable
jmp     .L3            ; jump to L3 to handle small array without using vector compatible registers


