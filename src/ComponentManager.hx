import luxe.Entity;
import luxe.Component;
import haxe.rtti.Meta;
import luxe.Scene;

//!!!!!! this whole class should be rewritten out of existence - these could be static public methods probably
//!!! everything in this class probably needs to be renamed !!!
class ComponentManager {
	public var componentData : Array<{name:String, components:Array<Dynamic>}> = []; //hack attack

	//this could be better (needs to incorporate name changes)
	public function updateComponentFromJson(name, jsonData) {
		for (d in componentData) {
			if (d.name == name) {
				d.components = jsonData.components;
			}
		}
	}

	public function addComponentFromJson(jsonData) {
		//DOESN'T AVOID DUPES !!
		componentData.push(jsonData);
	}

	//noDupes is a hack - please get rid of as soon as possible
	public function updateFromJson(jsonData, ?noDupes:Bool) {
		if (noDupes == null) noDupes = false;
		if (noDupes) { //HORRIFYING HACK
			for (d in cast(jsonData, Array<Dynamic>)) {
				if (getEntryByName(d.name) != null) {
					var e = Luxe.scene.entities.get(d.name); //assume the main scene contains the new dupes
					
					Luxe.scene.remove(e);
					e.name = e.name + "x"; //just keep adding Xs to get "unique" names
					Luxe.scene.add(e);

					d.name = e.name;
					componentData.push( d );
				}
				else {
					componentData.push( d );
				}
			}
		}
		else if (componentData == null) {
			componentData = jsonData;
		}
		else {
			for (d in cast(jsonData, Array<Dynamic>)) {
				componentData.push( d );
			}
		}
	}	

	public function getEntry(e : Entity) {
		var entry = null;
		for (d in componentData) {
			if (d.name == e.name) entry = d; //no safety checks !!!
		}
		return entry;
	}

	public function getEntryByName(n : String) {
		var entry = null;
		for (d in componentData) {
			if (d.name == n) entry = d; //no safety checks !!!
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

	function getComponentsOnlyFromScene(scene: Scene) {
		var componentsOnlyFromScene = [];
		for (entry in componentData) {
			if (scene.entities.exists(entry.name)) {
				componentsOnlyFromScene.push(entry);
			}
		}
		trace("COMPONENTS FROM " + scene.name + " : " + componentsOnlyFromScene.length);
		return componentsOnlyFromScene;
	}

	public function jsonRepresentation(?scene : Scene) {
		if (scene == null) scene = Luxe.scene;
		return getComponentsOnlyFromScene(scene);
	}

	//the typeName thing is a fucking hack btw, please remove, kthx
	public function activateComponents(?scene : Scene, ?typeName : String) {
		if (scene == null) scene = Luxe.scene;

		trace("ACTIVATE");
		trace(scene);

		for (entry in componentData) {
			var e = scene.entities.get(entry.name);
			trace(e);
			
			if (e != null) {
				for (c in entry.components) {
					trace("c " + c.name);
					if (e.has(c.name)) {
						//later: remove and re-add???
					}
					else {

						if (typeName == null || c.name == typeName) {
							var newComponent:Component = Type.createInstance(Type.resolveClass("components." + c.name), [c]);
							e.add(newComponent);
						}

					}
				}
			}
			
		}

		trace("DONE");
	}

	public function deactivateComponents(?scene : Scene) {
		if (scene == null) scene = Luxe.scene;

		for (entry in componentData) {
			var e = scene.entities.get(entry.name);
			if (e != null) {
				for (c in entry.components) {
					if (e.has(c.name)) e.remove(c.name);
				}
			}
		}
	}
}