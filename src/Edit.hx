import luxe.Visual;
import luxe.Color;
import phoenix.Batcher;

//import LayerManager;

using utilities.PolygonGroupExtender;
using utilities.VectorExtender;

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

	public static function AddLayer(layerList, layer, index) {
		return new AddLayerEdit(layerList, layer, index);
	}

	public static function RemoveLayer(layerList, index) {
		return new RemoveLayerEdit(layerList, index);
	}

	public static function MoveLayer(layerList, index, dir) {
		return new MoveLayerEdit(layerList, index, dir);
	}

	public static function ChangeColor(layer, color) {
		return new ChangeColorEdit(layer, color);
	}
}

class AddLayerEdit extends Edit {
	//var layerManager:LayerManager;
	var layerList:Array<Polygon>;
	var layer:Polygon;
	var layerIndex:Int;

	override public function new (layerList:Array<Polygon>, layer:Polygon, layerIndex:Int) {
		this.layerList = layerList;
		this.layer = layer;
		this.layerIndex = layerIndex;

		super();
	}

	override public function redo() {	
		super.redo();

		//layerManager.addLayer(layer, layerIndex);

		//hack, check for parent (move this hack further down??)
		if (layerList.length > 0 && layerList[0].parent != null) {
			var parent = layerList[0].parent;
			
			layer.transform.pos = layer.transform.pos.toLocalSpace(parent.transform);

			for (l in layerList) {
				l.parent = null;
			}
			layerList.insert(layerIndex, layer);
			for (l in layerList) {
				l.parent = parent; //this is probably the worst way to do this???
			}

			cast(parent, Polygon).recenter();
			//layer.parent = parent;
		}
		else {
			layerList.insert(layerIndex, layer);	
		}

		Main.instance.rootLayers.setDepthsRecursive(0, 1);

		Luxe.renderer.batcher.add(layer.geometry);
	}

	override public function undo() {
		super.undo();

		//layerManager.removeLayer(layer);
		if (layer.parent != null) {
			layer.parent = null;
		}
		layerList.remove(layer);

		Luxe.renderer.batcher.remove(layer.geometry);
	}
}

//this probably needs updating
class RemoveLayerEdit extends Edit {
	//var layerManager:LayerManager;
	var layerList:Array<Polygon>;
	var layer:Polygon;
	var layerIndex:Int;
	var batcher: Batcher;

	override public function new (layerList:Array<Polygon>, layerIndex:Int) {
		this.layerList = layerList;
		this.layer = layerList[layerIndex]; //layerManager.getLayer(layerIndex);
		this.layerIndex = layerIndex;
		this.batcher = this.layer.geometry.batchers[0];

		super();
	}

	override public function redo() {	
		super.redo();

		//layerManager.removeLayer(layer);
		layerList.remove(layer);
		layer.parent = null; //it might or might not have a parent
		batcher.remove(layer.geometry);
		//remove children too (is this really the right place for this???)
		for (c in layer.children) {
			batcher.remove( cast(c, Visual).geometry );
		}
	}

	override public function undo() {
		super.undo();

		//layerManager.addLayer(layer, layerIndex-1);
		layerList.insert(layerIndex-1, layer);
		batcher.add(layer.geometry);
		//add children here?
		for (c in layer.children) {
			batcher.add( cast(c, Visual).geometry );
		}
	}
}

class MoveLayerEdit extends Edit {
	//var layerManager:LayerManager;
	var layerList:Array<Polygon>;
	var layer:Polygon;
	var startIndex:Int;
	var endIndex:Int;

	override public function new (layerList:Array<Polygon>, layerIndex:Int, dir:Int) {
		this.layerList = layerList;
		this.layer = layerList[layerIndex]; //layerManager.getLayer(layerIndex);
		this.startIndex = layerIndex;
		this.endIndex = layerIndex + dir;

		super();
	}

	override public function redo() {	
		super.redo();

		//layerManager.swapLayers(startIndex, endIndex);
		layerList.swap(startIndex, endIndex);
		layerList.setDepths(0,1);
	}

	override public function undo() {
		super.undo();

		//layerManager.swapLayers(endIndex, startIndex);
		layerList.swap(endIndex, startIndex);
		layerList.setDepths(0,1);
	}
}

class ChangeColorEdit extends Edit {
	var layer:Polygon;
	var c1:Color;
	var c2:Color;

	override public function new (layer:Polygon, newColor:Color) {
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