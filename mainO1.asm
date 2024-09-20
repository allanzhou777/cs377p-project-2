@ -----high level overview-----
@ There are two parameters
@ The first is 'input', a 64-bit address to an array, which is passed in
@ register rdi. The second is 'length', a 32-bit integer representing the
@ number of elements in the array, which is passed in register esi. 

@ The code can be separated into five sections. 


@ testl   %esi, %esi      
@ jle     .L4             
@ In the first section, we do a check on 'length' to see if length is less 
@ than or equal to zero. If that's the case, we jump to L4, where 0 is moved 
@ into register edx. The code then jumps to L1 where this 0 is moved to the 
@ first register eax, which is where our return value of 0 will be contained.
@ 0 is the expected output, since summing no items will have a sum of 0. 


@ movq    %rdi, %rax      
@ leal    -1(%rsi), %edx  
@ leaq    4(%rdi,%rdx,4), %rcx  
@ movl    $0, %edx        
@ If we find that the 'length' is a positive integer, we jump to the second 
@ section, move around some variables and do some calculations for the third section (in
@ which we repeatedly iterate over the array). First, the base address of the array
@ in register rdi is moved to rax. This pointer will be used to interate through the array. Then, we calculate the address 
@ of the last element. We do this by calculating 'length - 1' and moving this to edx. We 
@ then multiply by 4 since each element is 4 bytes away from the next/previous. The 
@ final address is stored in rcx, which we'll use to determine if we've reached the end. Finally, we initialize edx, or the sum variable, to 0 before 
@ we begin summing. 


@ .L3:
@ addl    (%rax), %edx   
@ addq    $4, %rax       
@ cmpq    %rcx, %rax     
@ jne     .L3            

@ In the third section, we iterate over each item and add it's
@ value to the sum variable. We do this by adding the value stored
@ in address rax (input[i]) to edx (the sum variable). Then, we
@ increment the address by 4 (since sizeof(int) == 4). We do a check to see
@ if we've reached the end by comparing our updated address (rax)
@ to the end we calculated in second section (rcx). If the two aren't equal, we continue looping
@ and repeat the process for the next element of input.


@ .L1:
@ movl    %edx, %eax     
@ ret                    

@ By this point, we've reached the end of the array and our sum
@ variable (edx) contains what we want. We move edx to the first
@ register eax where it will be outputted when we return.


@ .L4:
@ movl    $0, %edx       
@ jmp     .L1            

@ We only take this 5th section if we branched earlier due to length being zero or negative. 
@ In this case, we set the sum to 0, and jump to L1,
@ where the 0 sum is placed in the appropriate register for return.





@ -----line by line comments-----
testFunction:
testl   %esi, %esi @ compute length & length, and sets flags
jle     .L4 @ uses flags to compare length of array to 0. If length <= 0, then jump to L4. Else, just continue to next line

movq    %rdi, %rax @ move a pointer to the start of the array, which is the 'input' pointer
leal    -1(%rsi), %edx @ calculate (length - 1), put that value into edx
leaq    4(%rdi,%rdx,4), %rcx @ calculate the address of the last element by taking starting address and adding 4 * (length - 1), putting that address into rcx
movl    $0, %edx @ initialize the sum variable to 0, stored in edx

.L3:
addl    (%rax), %edx @ add the integer stored at array with address in rax, aka input[i], to the sum variable
addq    $4, %rax @ move forward 4 bytes == sizeof(int)
cmpq    %rcx, %rax @ do a check to see if we've reached the address of the last element
jne     .L3 @ if we haven't reached the end, go to L3 and repeat for the next element of input

.L1:
movl    %edx, %eax @ we've reached the end of the array, so move the sum variable to the first register eax
ret @ return with the sum variable stored in the first register

.L4:
movl    $0, %edx @ if the length <= 0, we initialize sum to 0
jmp     .L1 @ jump to L1, where we move sum and return. 