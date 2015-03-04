package components;
import components.EditorComponent;

import luxe.Component;
import luxe.utils.Maths;

import Polygon;

class MosaicComponent extends EditorComponent {

	var polygon : Polygon;

	override function init() {
		polygon = cast entity;

		var i = 0;
		while (i < polygon.geometry.vertices.length) {
			var v0 = polygon.geometry.vertices[i];
			var v1 = polygon.geometry.vertices[i+1];
			var v2 = polygon.geometry.vertices[i+2];

			var colorTmp = v0.color.toColorHSV();
			colorTmp.s = Maths.random_float(0.5, 1.0);

			v0.color = colorTmp;
			v1.color = colorTmp;
			v2.color = colorTmp;

			i += 3;
		}
	}

	override function update(dt : Float) {
		
	}

	override function onremoved() {
	}
}
