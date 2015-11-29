#ifndef FIFOBUF_H
#define FIFOBUF_H

// Generic FIFO buffer implementation
// Cannot trust global constructors on NXP chip currently (have not hooked them up)
// Buffer size must be a power of 2 <= 256

template<int buffersize>
class FifoBuffer
{
public:
	volatile unsigned char buffer[buffersize];
	volatile unsigned short start, end;
	static const unsigned short buffermask = (unsigned short)(buffersize-1);
	// Start is the next byte to remove from the buffer, and end is the next byte to add to the buffer
	// So buffer writer controls end, and buffer reader controls end
	void init()
	{
		start = end = 0;
	}
	int Length() 
	{ 
		return (end - start) & buffermask; 
	}
	int Free()
	{
		return buffersize - Length() - 1;
	}
	int CanRead()
	{
		return start != end;
	}
	int CanWrite()
	{
		return ((end + 1) & buffermask) != start;
	}
	unsigned char ReadByte()
	{
		if(start == end) return 0; // Unable to read
		unsigned char out = buffer[start];
		start = (start + 1) & buffermask;
		return out;
	}
	unsigned char PeekByte()
	{
		return buffer[start]; // May be incorrect if cannot read. Leave this to a higher layer to determine.
	}
	unsigned char PeekN(int n)
	{
		int temp = (start+n)&buffermask;
		return buffer[temp]; // May be incorrect if cannot read. Leave this to a higher layer to determine.
	}
	void WriteByte(unsigned char b)
	{
		unsigned short newend = (end + 1) & buffermask;
		if(newend != start)
		{
			buffer[end] = b;
			end = newend;
		}
	}
	
	// Requires the correct number of bytes to be in the array. Does not check.
	void WriteBytes(unsigned char* bytes, int count)
	{
		unsigned short newend = (end + count) & buffermask;
		for(int i=0;i<count; i++)
		{
			buffer[(end+i)&buffermask] = bytes[i]; 
		}
		end = newend;
	}
	
	// Requires the correct number of bytes to be in the array. Does not check.
	void ReadBytes(unsigned char* bytes, int count)
	{
		unsigned short newstart = (start + count) & buffermask;
		for(int i=0;i<count; i++)
		{
			bytes[i] = buffer[(start+i)&buffermask]; 
		}
		start = newstart;
	}	

};

#endif
