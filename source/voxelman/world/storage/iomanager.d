/**
Copyright: Copyright (c) 2016 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.world.storage.iomanager;

import std.experimental.logger;
import std.experimental.allocator.mallocator;
import std.bitmanip;
import std.array : empty;
import std.traits;

import cbor;
import voxelman.container.buffer;


alias SaveHandler = void delegate(ref PluginDataSaver);
alias LoadHandler = void delegate(ref PluginDataLoader);

final class IoManager
{
	package(voxelman.world) LoadHandler[] worldLoadHandlers;
	package(voxelman.world) SaveHandler[] worldSaveHandlers;
	StringMap stringMap;

	auto dbKey = IoKey(null);
	void loadStringKeys(ref PluginDataLoader loader) {
		stringMap.load(loader.readEntryDecoded!(string[])(dbKey));
		if (stringMap.strings.length == 0) {
			stringMap.put(null); // reserve 0 index for string map
		}
	}

	void saveStringKeys(ref PluginDataSaver saver) {
		saver.writeEntryEncoded(dbKey, stringMap.strings);
	}

public:
	this()
	{
		stringMap.put(null); // reserve 0 index for string map
		worldLoadHandlers ~= &loadStringKeys;
		worldSaveHandlers ~= &saveStringKeys;
	}

	void registerWorldLoadSaveHandlers(LoadHandler loadHandler, SaveHandler saveHandler)
	{
		worldLoadHandlers ~= loadHandler;
		worldSaveHandlers ~= saveHandler;
	}
}

struct IoKey {
	string str;
	uint id = uint.max;
}

struct StringMap {
	private Buffer!string array;
	private uint[string] map;

	private void load(string[] ids) {
		array.clear();
		foreach(str; ids) {
			put(str);
		}
	}

	private string[] strings() {
		return array.data;
	}


	private uint put(string key) {
		uint id = cast(uint)array.data.length;
		map[key] = id;
		array.put(key);
		return id;
	}

	private uint get(ref IoKey key) {
		if (key.id == uint.max) {
			key.id = map.get(key.str, uint.max);
			if (key.id == uint.max) {
				key.id = put(key.str);
			}
		}
		return key.id;
	}
}

struct PluginDataSaver
{
	StringMap* stringMap;
	private Buffer!ubyte buffer;
	private size_t prevDataLength;

	// HACK, duplicate
	ubyte[16] formKey(ref IoKey ioKey) {
		return formWorldKey(stringMap.get(ioKey));
	}

	Buffer!ubyte* beginWrite() {
		prevDataLength = buffer.data.length;
		return &buffer;
	}

	void endWrite(ref IoKey key) {
		uint entrySize = cast(uint)(buffer.data.length - prevDataLength);
		buffer.put(*cast(ubyte[4]*)&entrySize);
		buffer.put(formKey(key));
	}

	void writeEntryEncoded(T)(ref IoKey key, T data) {
		beginWrite();
		encodeCbor(buffer, data);
		endWrite(key);
	}

	void writeMapping(T)(ref IoKey key, T mapping)
		if (__traits(isSame, TemplateOf!T, Mapping))
	{
		auto sink = beginWrite();
		encodeCborArrayHeader(sink, mapping.infoArray.length);
		foreach(const ref info; mapping.infoArray)
		{
			encodeCborString(sink, info.name);
		}
		endWrite(key);
	}

	void reset() @nogc {
		buffer.clear();
	}

	int opApply(int delegate(ubyte[16] key, ubyte[] data) dg)
	{
		ubyte[] data = buffer.data;
		while(!data.empty)
		{
			ubyte[16] key = data[$-16..$];
			uint entrySize = *cast(uint*)(data[$-4-16..$-16].ptr);
			ubyte[] entry = data[$-4-16-entrySize..$-4-16];
			auto result = dg(key, entry);

			data = data[0..$-4-16-entrySize];

			if (result) return result;
		}
		return 0;
	}
}

unittest
{
	PluginDataSaver saver;
	StringMap stringMap;
	saver.stringMap = &stringMap;

	auto dbKey1 = IoKey("Key1");
	saver.writeEntryEncoded(dbKey1, 1);

	auto dbKey2 = IoKey("Key2");
	auto sink = saver.beginWrite();
		encodeCbor(sink, 2);
	saver.endWrite(dbKey2);

	// iteration
	foreach(ubyte[16] key, ubyte[] data; saver) {
		//
	}
	saver.reset();
}

struct PluginDataLoader
{
	StringMap* stringMap;
	ubyte[] delegate(ubyte[16] key) getter;

	// HACK, duplicate
	ubyte[16] formKey(ref IoKey ioKey) {
		return formWorldKey(stringMap.get(ioKey));
	}

	ubyte[] readEntryRaw(ref IoKey key) {
		auto data = getter(formKey(key));
		return data;
	}

	/// decodes entry if data in db is not empty. Leaves value untouched otherwise.
	void readEntryDecoded(T)(ref IoKey key, ref T value) {
		ubyte[] data = readEntryRaw(key);
		if (data)
			decodeCbor!(Yes.Duplicate)(data, value);
	}

	T readEntryDecoded(T)(ref IoKey key) {
		ubyte[] data = readEntryRaw(key);
		T value;
		if (data) {
			decodeCbor!(Yes.Duplicate)(data, value);
		}
		return value;
	}

	void readMapping(T)(ref IoKey key, ref T mapping)
		if (__traits(isSame, TemplateOf!T, Mapping))
	{
		ubyte[] data = readEntryRaw(key);
		if (data)
		{
			string[] value;
			decodeCbor!(Yes.Duplicate)(data, value);

			mapping.setMapping(value);
		}
	}
}

ubyte[16] formWorldKey(uint key) {
	ubyte[16] res;
	(*cast(ulong[2]*)res.ptr)[0] = key;
	(*cast(ulong[2]*)res.ptr)[1] = 0;
	return res;
}
