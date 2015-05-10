import luxe.Visual;
import luxe.Color;
import phoenix.Batcher;

import LayerManager;

class Edit {
	public static var doneList:Array<Edit> = [];
	public static var undoneList:Array<Edit> = [];

	public function new() {
		//when you make a new edit, you can no longer redo previously undone edits
		undoneList = [];

		redo(); //do the edit for the first time immediately
	}

	public function redo() {
		if (undoneList.indexOf(this) > -1) {
			undoneList.remove(this);
		}
		doneList.push(this);
	}

	public function undo() {
		if (doneList.indexOf(this) > -1) {
			doneList.remove(this);
		}
		undoneList.push(this);
	}

	public static function Undo() {
		if (doneList.length > 0) {
			doneList[doneList.length - 1].undo();
		}
	}

	public static function Redo() {
		if (undoneList.length > 0) {
			undoneList[undoneList.length - 1].redo();
		}
	}

	public static function AddLayer(layerManager, layer, index) {
		return new AddLayerEdit(layerManager, layer, index);
	}

	public static function RemoveLayer(layerManager, index) {
		return new RemoveLayerEdit(layerManager, index);
	}

	public static function MoveLayer(layerManager, index, dir) {
		return new MoveLayerEdit(layerManager, index, dir);
	}

	public static function ChangeColor(layer, color) {
		return new ChangeColorEdit(layer, color);
	}
}

class AddLayerEdit extends Edit {
	var layerManager:LayerManager;
	var layer:Visual;
	var layerIndex:Int;

	override public function new (layerManager:LayerManager, layer:Visual, layerIndex:Int) {
		this.layerManager = layerManager;
		this.layer = layer;
		this.layerIndex = layerIndex;

		super();
	}

	override public function redo() {	
		super.redo();

		layerManager.addLayer(layer, layerIndex);
		Luxe.renderer.batcher.add(layer.geometry);
	}

	override public function undo() {
		super.undo();

		layerManager.removeLayer(layer);
		Luxe.renderer.batcher.remove(layer.geometry);
	}
}

class RemoveLayerEdit extends Edit {
	var layerManager:LayerManager;
	var layer:Visual;
	var layerIndex:Int;
	var batcher: Batcher;

	override public function new (layerManager:LayerManager, layerIndex:Int) {
		this.layerManager = layerManager;
		this.layer = layerManager.getLayer(layerIndex);
		this.layerIndex = layerIndex;
		this.batcher = this.layer.geometry.batchers[0];

		super();
	}

	override public function redo() {	
		super.redo();

		layerManager.removeLayer(layer);
		batcher.remove(layer.geometry);
		//remove children too (is this really the right place for this???)
		for (c in layer.children) {
			batcher.remove( cast(c, Visual).geometry );
		}
	}

	override public function undo() {
		super.undo();

		layerManager.addLayer(layer, layerIndex-1);
		batcher.add(layer.geometry);
		//add children here?
		for (c in layer.children) {
			batcher.add( cast(c, Visual).geometry );
		}
	}
}

class MoveLayerEdit extends Edit {
	var layerManager:LayerManager;
	var layer:Visual;
	var startIndex:Int;
	var endIndex:Int;

	override public function new (layerManager:LayerManager, layerIndex:Int, dir:Int) {
		this.layerManager = layerManager;
		this.layer = layerManager.getLayer(layerIndex);
		this.startIndex = layerIndex;
		this.endIndex = layerIndex + dir;

		super();
	}

	override public function redo() {	
		super.redo();

		layerManager.swapLayers(startIndex, endIndex);
	}

	override public function undo() {
		super.undo();

		layerManager.swapLayers(endIndex, startIndex);
	}
}

class ChangeColorEdit extends Edit {
	var layer:Visual;
	var c1:Color;
	var c2:Color;

	override public function new (layer:Visual, newColor:Color) {
		this.layer = layer;
		this.c1 = layer.color.clone();
		this.c2 = newColor.clone();

		super();
	}

	override public function redo() {
		super.redo();

		layer.color = c2;
	}

	override public function undo() {
		super.undo();

		layer.color = c1;
	}
}