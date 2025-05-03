module main;

import std.stdio, std.concurrency, std.parallelism;

import buffer_pool;


void main()
{
	size_t CHUNK_SIZE = 1<<20;
	size_t CHUNK_COUNT = totalCPUs * 4;
	BufferPool pool = BufferPool(CHUNK_SIZE, CHUNK_COUNT);
}


