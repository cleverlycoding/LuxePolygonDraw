import luxe.Entity;
import luxe.Component;
import TestComponent; // hack/test

class ComponentManager {
	public var componentData = [];

	public function updateFromJson(jsonData) {
		componentData = jsonData;
	}	

	public function addEntity(e : Entity, name : String) {
		//this function is not "safe" -- it can create duplicate entries
		e.name = name;
		var exampleC = { 
			className : "Example", 
			options : {} 
		};
		var emptyComponentData = {
			name : name,
			components : [exampleC]
		};
		componentData.push(emptyComponentData);
	}

	public function jsonRepresentation() {
		return componentData;
	}

	public function activateComponents() {
		for (entry in componentData) {
			trace(entry.name);
			trace(Luxe.scene.entities);
			var e = Luxe.scene.entities.get(entry.name);
			for (c in entry.components) {
				trace(c.className);
				trace(Type.resolveClass(c.className));

				var newComponent:TestComponent = Type.createInstance(Type.resolveClass(c.className), [c.options]);
				//type specificity is temporary

				trace(newComponent);

				trace(newComponent.testMessage);
				
				trace(e);

				e.add(newComponent);

				trace("??");
			}
		}
	}

	public function deactivateComponents() {
		for (entry in componentData) {
			var e = Luxe.scene.entities.get(entry.name);
			for (c in entry.components) {
				e.remove(c.className);
			}
		}
	}
}