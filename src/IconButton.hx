import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;

using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.PolylineExtender;
using ledoux.UtilityBelt.FileInputExtender;
using ledoux.UtilityBelt.PolygonGroupExtender;

import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;

class IconButton extends Visual {
	
	public override function new(_options:luxe.options.VisualOptions, filename:String) {
		super(_options);

		trace("1");

		var input = File.read(filename, false);

		trace(input);

		trace("2");

		var pGroup = input.readScene();

		this.transform.pos = pGroup.center();

		for (poly in pGroup) {
			poly.parent = this;
		}

		input.close();
	}
}