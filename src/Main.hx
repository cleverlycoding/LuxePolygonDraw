//LUXE
import luxe.Input;
import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher; //necessary to access PrimitiveType

//HAXE
import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;

//ARL
import Polyline;
import Polygon;
import ColorPicker;
import Slider;
import Edit;
import LayerManager;

using ledoux.UtilityBelt.VectorExtender;

class Main extends luxe.Game {

	//drawing
	var curLine : Polyline;
	var minLineLength = 20;
	var isDrawing : Bool;

	//layers
	var layers = new LayerManager(0, 1, 1000);
	var aboveLayersDepth = 10001;
	var curLayer = 0;
	var selectedLayerOutline:Polyline;

	//color picker
	var picker : ColorPicker;
	var slider : Slider;
	var isPickingColor : Bool;
	var curColorIcon : QuadGeometry;
	var colorList : Array<ColorHSV> = [];
	var colorIndex : Int;

    //UI
    var uiBatcher : Batcher;

    override function ready() {
    	//instantiate objects
        selectedLayerOutline = new Polyline({depth: aboveLayersDepth}, []);

        //render settings
        Luxe.renderer.batcher.layer = 1;
        Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.2);
        Luxe.renderer.state.lineWidth(2);

        //UI
        createUI();        
    } //ready

    override function onkeydown(e:KeyEvent) {
    	if (e.keycode == Key.key_z) {
    		Edit.Undo();
    	}
    	else if (e.keycode == Key.key_x) {
    		Edit.Redo();
    	}
    	else if (e.keycode == Key.key_a) {
    		switchLayerSelection(-1);
    	}
    	else if (e.keycode == Key.key_s) {
    		switchLayerSelection(1);
    	}
    	else if (e.keycode == Key.key_p) {
    		if (layers.getNumLayers() > 0) {	
	    		Edit.RemoveLayer(layers, curLayer);
	    		switchLayerSelection(-1);
    		}
    	}
    	else if (e.keycode == Key.key_q) {
    		if (curLayer > 0) {
	    		Edit.MoveLayer(layers, curLayer, -1);
	    		switchLayerSelection(-1);
    		}
    	}
    	else if (e.keycode == Key.key_w) {
    		if (curLayer < layers.getNumLayers() - 1) {
	    		Edit.MoveLayer(layers, curLayer, 1);	
	    		switchLayerSelection(1);
    		}
    	}
    	else if (e.keycode == Key.key_l) {
    		if (isPickingColor) {
    			addColorToList(picker.pickedColor);
    		}
    		colorPickerMode(!isPickingColor);
    	}
    	else if (e.keycode == Key.key_j) {
    		//prev color
    		navigateColorList(-1);
    	}
    	else if (e.keycode == Key.key_k) {
    		//next color
    		navigateColorList(1);
    	}
    	else if (e.keycode == Key.key_m) {
    		//pick up color
    		var tmp = layers.getLayer(curLayer).color.clone().toColorHSV();
    		picker.pickedColor = tmp;
    		slider.value = tmp.v;

    		addColorToList(picker.pickedColor);
    	}
    	else if (e.keycode == Key.key_n) {
    		//drop color
    		//layers.getLayer(curLayer).color = picker.pickedColor.clone();
    		Edit.ChangeColor(layers.getLayer(curLayer), picker.pickedColor.clone());
    	}
    	else if (e.keycode == Key.key_1) {
    		//save
    		var output = File.write(Luxe.core.app.io.platform.dialog_save() + ".json", false);

    		var outObj = layers.getJsonRepresentation();
    		var outStr = haxe.Json.stringify(outObj);
    		output.writeString(outStr);

    		output.close();
		}
		else if (e.keycode == Key.key_2) {
			//load
			var input = File.read(Luxe.core.app.io.platform.dialog_open(), false);

			var inStr = input.readLine();
			var inObj = haxe.Json.parse(inStr);

			for (l in cast(inObj.layers, Array<Dynamic>)) {
				Edit.AddLayer(layers, new Polygon({}, [], l), curLayer+1);
    			switchLayerSelection(1);
			}

			input.close();
		}
        else if (e.keycode == Key.minus) {
            //zoom out
            Luxe.renderer.camera.zoom *= 0.5;
        }
        else if (e.keycode == Key.equals) {
            //zoom in
            Luxe.renderer.camera.zoom *= 2;
        }
    }

    override function onkeyup(e:KeyEvent) {
        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }
    } //onkeyup

    override function update(dt:Float) {

    } //update

    override function onmousedown(e:MouseEvent) {
        if (!isPickingColor) { //a crappy way to do this, I know

            var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);

            if (!isDrawing) {
                curLine = new Polyline({color: picker.pickedColor.clone(), depth: aboveLayersDepth+1}, [mousepos]);
                isDrawing = true;
            }
            else {
                addPointToCurrentLine(mousepos);
            }
        }
    }

    override function onmousemove(e:MouseEvent) {
        if (!isPickingColor) {  
            if (isDrawing && Luxe.input.mousedown(1)) {

                var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
                if (curLine.getEndPoint().distance(mousepos) >= minLineLength) {
                    addPointToCurrentLine(mousepos);
                }
            }
        }
    }

    override function onmouseup(e:MouseEvent) {

    }

    function createUI () {
        //separate batcher to layer UI over drawing space
        uiBatcher = Luxe.renderer.create_batcher({name:"uiBatcher", layer:2});

        //UI
        picker = new ColorPicker({
            scale : new Vector(Luxe.screen.h/4,Luxe.screen.h/4), /*separate radius from scale??*/
            pos : new Vector(Luxe.screen.w/2,Luxe.screen.h/2),
            batcher : uiBatcher
        });

        slider = new Slider({
            size : new Vector(10, Luxe.screen.h * 0.5),
            pos : new Vector(Luxe.screen.w * 0.8, Luxe.screen.h/2),
            batcher: uiBatcher
        });

        curColorIcon = Luxe.draw.box({w: 30, h: 30, x: 0, y: 0, batcher: uiBatcher});
        curColorIcon.color = picker.pickedColor;

        //UI events
        slider.onSliderMove = function() {
            picker.setV(slider.value);
        };

        picker.onColorChange = function() {
            slider.setOutlineHue(picker.pickedColor.h);
        };

        //turn off color picker
        colorPickerMode(false);
    }

    function addColorToList(c:ColorHSV) {
    	colorList.push(c.clone());
    	colorIndex = colorList.length-1; //move back to top of the list
    	//add something to tie this function to the color picker? (force color picker to switch colors for example)
    }

    function navigateColorList(dir:Int) {
    	colorIndex += dir;
    	if (colorIndex < 0) colorIndex = 0;
    	if (colorIndex >= colorList.length) colorIndex = colorList.length-1;

    	var c = colorList[colorIndex];

    	picker.pickedColor = c;
    	slider.value = c.v;
    }

    function colorPickerMode(on:Bool) {
    	isPickingColor = on;
    	picker.visible = on;
    	slider.visible = on;
    }

    function switchLayerSelection(dir:Int) {
    	curLayer += dir;

    	if (curLayer < 0) curLayer = 0;
    	if (curLayer >= layers.getNumLayers()) curLayer = layers.getNumLayers()-1;

    	if (layers.getNumLayers() > 0) {	
	    	var loop = (cast layers.getLayer(curLayer)).getPoints();
	    	//horrible hacks to avoid aliasing :/
	    	var start = loop[0];
	    	selectedLayerOutline.setPoints([]);
	    	for (point in loop) {
	    		selectedLayerOutline.addPoint(point);
	    	}
	    	selectedLayerOutline.addPoint(start);
    	}
    	else {
	    	selectedLayerOutline.setPoints([]);
    	}
    }

    function addPointToCurrentLine(p:Vector) {
    	curLine.addPoint(p);

    	var test = curLine.getPoints().findPolylineIntersections();
    	if (test.intersects) {
    		var newPolylines = curLine.getPoints().splitPolyline(test.intersectionList[0]);

    		Edit.AddLayer(layers, new Polygon({color: curLine.color}, newPolylines.closedLine), curLayer+1);
    		switchLayerSelection(1);

    		//remove drawing line
    		endDrawing();
    	}
    }

    function endDrawing() {
		Luxe.renderer.batcher.remove(curLine.geometry);
		curLine = null;
		isDrawing = false;
    }

} //Main	