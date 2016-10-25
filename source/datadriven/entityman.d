module datadriven.entityman;

import datadriven.api;
import datadriven.storage;
import datadriven.query;

struct ComponentInfo
{
	string name;
	void delegate(EntityId) remove;
	void* storage;
}

alias ComponentStorage(T) = CustomHashmapComponentStorage!T;

struct TypedComponentInfo(C)
{
	string name;
	void delegate(EntityId) remove;
	ComponentStorage!C* storage;
	static typeof(this)* fromUntyped(ComponentInfo* untyped)
	{
		return cast(typeof(this)*)untyped;
	}
}

struct EntityManager
{
	ComponentInfo*[TypeInfo] componentMap;

	void registerComponent(C)(string name)
	{
		assert(typeid(C) !in componentMap);
		auto storage = new ComponentStorage!C;
		componentMap[typeid(C)] = new ComponentInfo(name, &storage.remove, storage);
	}

	void add(Components...)(EntityId eid, Components components)
	{
		foreach(i, C; Components)
		{
			ComponentInfo* untyped = componentMap[typeid(C)];
			auto typed = TypedComponentInfo!C.fromUntyped(untyped);
			typed.storage.add(eid, components[i]);
		}
	}

	C* get(C)(EntityId eid)
	{
		ComponentInfo* untyped = componentMap[typeid(C)];
		auto typed = TypedComponentInfo!C.fromUntyped(untyped);
		return typed.storage.get(eid);
	}

	void remove(EntityId eid)
	{
		foreach(info; componentMap.byValue)
		{
			info.remove(eid);
		}
	}

	auto query(Components...)()
	{
		// generate variables for typed storages
		mixin(genTempComponentStorages!Components);
		// populate variables
		foreach(i, C; Components)
		{
			ComponentInfo* untyped = componentMap[typeid(C)];
			mixin(genComponentStorageName!(ComponentStorage!C, i)) =
				TypedComponentInfo!C.fromUntyped(untyped).storage;
		}
		// construct query with storages
		return mixin(genQueryCall!Components);
	}

	void serialize(Sink)(Sink sink)
	{

	}

	void deserialize(ubyte[] input)
	{

	}
}

import std.conv : to;
string genTempComponentStorages(Components...)()
{
	string result;

	foreach(i, C; Components)
	{
		result ~= "ComponentStorage!(Components[" ~ i.to!string ~ "])* " ~
			genComponentStorageName!(ComponentStorage!C, i) ~ ";\n";
	}

	return result;
}

string genQueryCall(Components...)()
{
	string result = "componentQuery(";

	foreach(i, C; Components)
	{
		result ~= "*" ~ genComponentStorageName!(ComponentStorage!C, i) ~ ",";
	}
	result ~= ")";

	return result;
}
