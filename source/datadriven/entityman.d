module datadriven.entityman;

import datadriven.api;
import datadriven.storage;
import datadriven.query;
import voxelman.container.buffer;
import voxelman.world.storage.iomanager;

private struct ComponentInfo
{
	IoKey dbKey;
	void delegate(EntityId) remove;
	void delegate() removeAll;
	void delegate(Buffer!ubyte*) serialize;
	void delegate(ubyte[]) deserialize;
	void* storage;
}

enum bool isFlagComponent(C) = C.tupleof.length == 0;

private struct _Totally_empty_struct {}
static assert(isFlagComponent!_Totally_empty_struct);

template ComponentStorage(C)
{
	static if(isFlagComponent!C)
		alias ComponentStorage = EntitySet;
	else
		alias ComponentStorage = CustomHashmapComponentStorage!C;
}

private struct TypedComponentInfo(C)
{
	IoKey dbKey;
	void delegate(EntityId) remove;
	void delegate() removeAll;
	void delegate(Buffer!ubyte*) serialize;
	void delegate(ubyte[]) deserialize;
	ComponentStorage!C* storage;

	static typeof(this)* fromUntyped(ComponentInfo* untyped)
	{
		return cast(typeof(this)*)untyped;
	}
}

/// Convenience type for centralized storage and management of entity components.
struct EntityManager
{
	private ComponentInfo*[TypeInfo] componentMap;

	/// Before using component type in every other method, register it here.
	/// name is used for (de)serialization.
	void registerComponent(C)(string name)
	{
		assert(typeid(C) !in componentMap);
		auto storage = new ComponentStorage!C;
		componentMap[typeid(C)] =
			new ComponentInfo(
				IoKey(name),
				&storage.remove,
				&storage.removeAll,
				&storage.serialize,
				&storage.deserialize,
				storage);
	}

	/// Returns pointer to the storage of components C.
	/// Storage type depends on component type (flag or not).
	auto getComponentStorage(C)()
	{
		ComponentInfo* untyped = componentMap[typeid(C)];
		return TypedComponentInfo!C.fromUntyped(untyped).storage;
	}

	/// Add or set list of components for entity eid.
	void set(Components...)(EntityId eid, Components components)
	{
		foreach(i, C; Components)
		{
			static if(isFlagComponent!C)
				getComponentStorage!C().set(eid);
			else
				getComponentStorage!C().set(eid, components[i]);
		}
	}

	/// Returns pointer to the component of type C.
	/// Returns null if entity has no such component.
	/// Works only with non-flag components.
	C* get(C)(EntityId eid)
	{
		return getComponentStorage!C().get(eid);
	}

	/// Used to check for presence of given component or flag.
	bool has(C)(EntityId eid)
	{
		return cast(bool)getComponentStorage!C().get(eid);
	}

	/// Removes all components for given eid.
	void remove(EntityId eid)
	{
		foreach(info; componentMap.byValue)
		{
			info.remove(eid);
		}
	}

	/// Removes all components of all types.
	void removeAll()
	{
		foreach(info; componentMap.byValue)
		{
			info.removeAll();
		}
	}

	/// Returns query object for given set of component types for iteration with foreach.
	auto query(Components...)()
	{
		// generate variables for typed storages
		mixin(genTempComponentStorages!Components);
		// populate variables
		foreach(i, C; Components)
		{
			mixin(genComponentStorageName!(ComponentStorage!C, i)) =
				getComponentStorage!C();
		}
		// construct query with storages
		return mixin(genQueryCall!Components);
	}

	/// Serializes all component storages with given saver.
	void save(ref PluginDataSaver saver)
	{
		foreach(info; componentMap.byValue)
		{
			info.serialize(saver.beginWrite());
			saver.endWrite(info.dbKey);
		}
	}

	/// Deserializes all component storages from given loader.
	void load(ref PluginDataLoader loader)
	{
		foreach(info; componentMap.byValue)
		{
			info.deserialize(loader.readEntryRaw(info.dbKey));
		}
	}
}

private  string genTempComponentStorages(Components...)()
{
	import std.conv : to;
	string result;

	foreach(i, C; Components)
	{
		result ~= "ComponentStorage!(Components[" ~ i.to!string ~ "])* " ~
			genComponentStorageName!(ComponentStorage!C, i) ~ ";\n";
	}

	return result;
}

private string genQueryCall(Components...)()
{
	string result = "componentQuery(";

	foreach(i, C; Components)
	{
		result ~= "*" ~ genComponentStorageName!(ComponentStorage!C, i) ~ ",";
	}
	result ~= ")";

	return result;
}
