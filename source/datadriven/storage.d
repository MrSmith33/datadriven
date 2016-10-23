module datadriven.storage;

import datadriven.api;

struct HashmapComponentStorage(ComponentType)
{
	private ComponentType[EntityId] components;

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
struct CustomHashmapComponentStorage(ComponentType)
{
	private HashMap!(EntityId, ComponentType) components;

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
