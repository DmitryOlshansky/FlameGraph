module buffer_pool;


import core.stdc.stdlib;
import core.sync;

static struct BufferEntry {
    char* slice;
    private BufferEntry* next;
}

struct BufferPool {
    this(size_t chunkSize, size_t count) 
    in (count > 0 && chunkSize > 0) {
        _chunkSize = chunkSize;
        _mtx = new Mutex();
        _cond = new Condition(_mtx);
        foreach (i; 0 .. count) {
            BufferEntry* ptr = new BufferEntry;
            ptr.slice = cast(char*)malloc(_chunkSize);            
            ptr.next = _freelist;
            _freelist = ptr;
        }
    }

    size_t chunkSize(){
        return _chunkSize;
    }

    BufferEntry* acquire() {
        _mtx.lock();
        scope(exit) _mtx.unlock();
        while (_freelist == null) {
            _cond.wait();
        }
        auto ptr = _freelist;
        _freelist = _freelist.next;
        return ptr;
    }

    void release(BufferEntry* e) {
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
    BufferEntry* _freelist;
    Condition _cond;
    Mutex _mtx;
}

version(unittest) {
    __gshared BufferPool pool;
    shared static this() {
        pool =  BufferPool(8, 10);
    }
}

unittest {
    import std.concurrency, std.exception;
    static void func(Tid parent) {
        BufferEntry*[10] array;
        foreach (i; 0..10) {
            array[i] = pool.acquire();
        }
        foreach (BufferEntry* key; array[]) {
            send(parent, cast(immutable)(key));
        }
        foreach (i; 0..10) {
            array[i] = pool.acquire();
        }
        foreach (BufferEntry* key; array[]) {
            send(parent, cast(immutable)(key));
        }
    }
    spawn(&func, thisTid);
    foreach (i; 0..10) {
        receive((immutable (BufferEntry)* e) {
            pool.release(cast(BufferEntry*)e);
        });
    }
    foreach (i; 0..10) {
        receive((immutable(BufferEntry)* e) {
            pool.release(cast(BufferEntry*)e);
        });
    }
}