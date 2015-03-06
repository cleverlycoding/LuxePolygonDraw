import luxe.Entity;
import luxe.Component;
import haxe.rtti.Meta;

//!!! everything in this class probably needs to be renamed !!!
class ComponentManager {
	public var componentData : Array<{name:String, components:Array<Dynamic>}> = []; //hack attack

	public function updateFromJson(jsonData) {
		componentData = jsonData;
	}	

	function getEntry(e : Entity) {
		var entry = null;
		for (d in componentData) {
			if (d.name == e.name) entry = d; //no safety checks !!!
		}
		return entry;
	}

	function addEntry(e : Entity) {
		//remove and re-add to register name change (hack)
		Luxe.scene.remove(e);
		e.name = "id" + componentData.length;
		Luxe.scene.add(e);
		
		var emptyComponentData = {
			name : e.name, //need a better way to set names eventually than the non-descriptive automatic ones
			components : []
		};
		componentData.push(emptyComponentData);
		return componentData[componentData.length - 1];
	}

	//there is probably a better way to do this (research haxe reflection in more depth -- maybe "properties can help")
	public function addComponent(e : Entity, className : String) {
		var entry = getEntry(e);
		if (entry == null) entry = addEntry(e);

		var classData = {
			name : className
		};

		//load class metadata
		var metadata = Meta.getFields(Type.resolveClass("components." + className));

		//populate editor fields
		for (fieldName in Reflect.fields(metadata)) {
			var field = Reflect.field(metadata, fieldName);

			if (Reflect.hasField(field, "editor")) { //make sure we're looking at the right type of meta property
				if (field.editor != null && field.editor.length > 0) { //use default value
					Reflect.setField(classData, fieldName, Reflect.field(metadata, fieldName).editor[0]);
				}
				else { //has no default value
					Reflect.setField(classData, fieldName, null);
				}
			}
		}

		entry.components.push(classData);
	}

	public function jsonRepresentation() {
		return componentData;
	}

	public function activateComponents() {
		for (entry in componentData) {
			var e = Luxe.scene.entities.get(entry.name);
			for (c in entry.components) {
				var newComponent:Component = Type.createInstance(Type.resolveClass("components." + c.name), [c]);
				e.add(newComponent);
			}
		}
	}

	public function deactivateComponents() {
		for (entry in componentData) {
			var e = Luxe.scene.entities.get(entry.name);
			for (c in entry.components) {
				e.remove(c.name);
			}
		}
	}
}