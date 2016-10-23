module datadriven.storage;

import datadriven.api;

struct HashmapComponentStorage(_ComponentType)
{
	private ComponentType[EntityId] components;
	alias ComponentType = _ComponentType;

	void add(EntityId eid, ComponentType component)
	{
		assert(eid !in components);
		components[eid] = component;
	}

	void remove(EntityId eid)
	{
		components.remove(eid);
	}

	size_t length() @property
	{
		return components.length;
	}

	ComponentType* get(EntityId eid)
	{
		return eid in components;
	}

	int opApply(int delegate(in EntityId, ref ComponentType) del) {
		foreach (pair; components.byKeyValue)
			if (auto ret = del(pair.key, pair.value()))
				return ret;
		return 0;
	}
}

static assert(isComponentStorage!(HashmapComponentStorage!int, int));

import hashmap;
struct CustomHashmapComponentStorage(_ComponentType)
{
	private HashMap!(EntityId, ComponentType) components;
	alias ComponentType = _ComponentType;

	void add(EntityId eid, ComponentType component)
	{
		assert(eid !in components);
		components[eid] = component;
	}

	void remove(EntityId eid)
	{
		components.remove(eid);
	}

	size_t length() @property
	{
		return components.length;
	}

	ComponentType* get(EntityId eid)
	{
		return eid in components;
	}

	int opApply(int delegate(in ref EntityId, ref ComponentType) del) {
		return components.opApply(del);
	}
}

static assert(isComponentStorage!(CustomHashmapComponentStorage!int, int));

import hashset;
struct EntitySet
{
	private HashSet!EntityId entities;

	void add(EntityId eid)
	{
		assert(eid !in entities);
		entities.put(eid);
	}

	void remove(EntityId eid)
	{
		entities.remove(eid);
	}

	size_t length() @property
	{
		return entities.length;
	}

	bool get(EntityId eid)
	{
		return eid in entities;
	}

	int opApply(int delegate(in EntityId) del) {
		return entities.opApply(del);
	}
}

static assert(isEntitySet!(EntitySet));
