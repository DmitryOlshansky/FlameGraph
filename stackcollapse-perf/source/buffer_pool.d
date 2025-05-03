module buffer_pool;


import core.stdc.stdlib;
import core.sync;

struct BufferPool {
    this(size_t chunkSize, size_t count) 
    in (count > 0 && chunkSize > 0) {
        _chunkSize = chunkSize;
        _mtx = new Mutex();
        _cond = new Condition(_mtx);
        foreach (i; 0 .. count) {
            Entry* ptr = new Entry;
            ptr.slice = cast(char*)malloc(_chunkSize);            
            ptr.next = _freelist;
            _freelist = ptr;
        }
    }

    static struct Entry {
        char* slice;
        private Entry* next;
    }

    size_t chunkSize(){
        return _chunkSize;
    }

    Entry* acquire() {
        _mtx.lock();
        scope(exit) _mtx.unlock();
        while (_freelist == null) {
            _cond.wait();
        }
        auto ptr = _freelist;
        _freelist = _freelist.next;
        return ptr;
    }

    void release(Entry* e) {
        _mtx.lock();
        scope(exit) _mtx.unlock();
        e.next = _freelist;
        _freelist = e;
        _cond.notify();
    }

    @disable this(this);

    ~this() {
        auto ptr = _freelist;
        while(ptr != null) {
            free(ptr.slice);
            ptr = ptr.next;
        }
    }

private:
    size_t _chunkSize;
    Entry* _freelist;
    Condition _cond;
    Mutex _mtx;
}