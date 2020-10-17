
#include <common/types.h>

class MemoryHandler {
protected:
   // Handled memory block
   typedef struct block {
        void *ptr;
        uint16_t size;
   } memoryBlock;
   
   // Handled blocks reference table
   memoryBlock *memoryBlocksReferenceTable;
public:
    MemoryHandler();
    ~MemoryHandler();

    void* malloc(size_t size);
    void* calloc(size_t num, size_t size);
    void* realloc(void *ptr, size_t new_size);
    void free(void* ptr);
    void* aligned_alloc(size_t alignment, size_t size);
};