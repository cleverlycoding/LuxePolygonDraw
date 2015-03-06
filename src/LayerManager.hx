import luxe.Visual;

class LayerManager {
	var layers:Array<Visual>;
	var baseDepth:Float;
	var depthIncrement:Float;
	var maxLayerNum:Int;

	public function new (baseDepth, depthIncrement, maxLayerNum) {
		layers = [];

		this.baseDepth = baseDepth;
		this.depthIncrement = depthIncrement;
		this.maxLayerNum = maxLayerNum;
	}

	public function swapLayers(i:Int, j:Int) {
		var tmp = layers[i];
		layers[i] = layers[j];
		layers[j] = tmp;
		setLayerDepth(layers[i], i);
		setLayerDepth(layers[j], j);
	}

	public function addLayer(l:Visual, ?i:Int) {
		if (layers.length < maxLayerNum) {	
			if (i != null && i < layers.length-1) {
				layers.insert(i, l);
				recalculateDepths();
			}
			else {
				layers.push(l);
				setLayerDepth(l, layers.length-1);
			}

			//Luxe.scene.add(l);
		}
	}

	public function removeLayer(l:Visual) {
		layers.remove(l);
		recalculateDepths();
	}

	public function getLayer(i:Int):Visual {
		return layers[i];
	}

	function setLayerDepth(l:Visual, i:Int) {
		l.geometry.depth = baseDepth + (depthIncrement * i);
	}

	public function getNumLayers(): Int {
		return layers.length;
	}

	public function getMaxDepth() : Float {
		return baseDepth + (depthIncrement * (maxLayerNum - 1));
	}

	function recalculateDepths() {
		var i = 0;
		for (l in layers) {
			setLayerDepth(l, i);
			i++;
		}
	}

	public function jsonRepresentation() {
		var jsonObj = {layers: []}
		for (l in layers) {
			var p = cast(l, Polygon);
			jsonObj.layers.push(p.jsonRepresentation());
		}
		return jsonObj;
	}
}