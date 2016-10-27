module datadriven.components;

import datadriven.api : Component;

@Component("component.Transform") struct Transform { float x, y, z; }
@Component("component.Velocity") struct Velocity  { float x, y, z; }
@Component("component.Velocity1") struct Velocity1  { float x, y, z; }
@Component("component.Velocity2") struct Velocity2  { float x, y, z; }
@Component("component.Velocity3") struct Velocity3  { float x, y, z; }

@Component("component.FlagComponent") struct FlagComponent {}
