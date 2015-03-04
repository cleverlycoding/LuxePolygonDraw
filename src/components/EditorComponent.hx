package components;

import luxe.Component;
import luxe.options.ComponentOptions;

import haxe.rtti.Meta;

class EditorComponent extends Component {
	override public function new(_options:ComponentOptions) {
		super(_options);

		updateEditorVariables(_options);
	}

	public function updateEditorVariables(jsonData) {
		//load class metadata
		var metadata = Meta.getFields(Type.getClass(this));

		//populate editor fields from JSON data
		for (fieldName in Reflect.fields(metadata)) {
			Reflect.setField(this, fieldName, Reflect.field(jsonData, fieldName));
		}
	}
}