//LUXE
import luxe.Input;
import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher;
import luxe.States;
import luxe.collision.Collision;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.utils.Maths;

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
using ledoux.UtilityBelt.PolylineExtender;
using ledoux.UtilityBelt.TransformExtender;

class Main extends luxe.Game {

	//drawing
	var curLine : Polyline;
	var minLineLength = 20;
	public var isDrawing : Bool;

	//layers
	var layers = new LayerManager(0, 1, 1000);
	var aboveLayersDepth = 10001;
	var curLayer = 0;
	var selectedLayerOutline:Polyline;

	//color picker
	var picker : ColorPicker;
	var slider : Slider;
	var curColorIcon : QuadGeometry;
	var colorList : Array<ColorHSV> = [];
	var colorIndex : Int;

    //editting
    var dragMouseStartPos : Vector;
    var selectedVertex : Int;
    var scaleDir : Vector;

    //ui
    var uiBatcher : Batcher;

    //states
    var machine : States;

    //collisions
    var polyCollision : CollisionPoly;

    override function ready() {

    	//instantiate objects
        selectedLayerOutline = new Polyline({depth: aboveLayersDepth}, []);

        //render settings
        Luxe.renderer.batcher.layer = 1;
        Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.2);
        Luxe.renderer.state.lineWidth(2);

        //UI
        createUI();  

        //STATES
        machine = new States({name:"statemachine"});
        machine.add(new DrawState({name:"draw"}));
        machine.add(new PickColorState({name:"pickcolor"}));
        machine.add(new EditState({name:"edit"}));
        machine.set("draw", this);
    } //ready

    override function onkeydown(e:KeyEvent) {
    }

    override function onkeyup(e:KeyEvent) {
        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }
    } //onkeyup

    override function update(dt:Float) {

    } //update

    override function onmousedown(e:MouseEvent) {
    }

    override function onmousemove(e:MouseEvent) {
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
    	picker.visible = on;
    	slider.visible = on;
    }

    function switchLayerSelection(dir:Int) {
    	curLayer += dir;

    	if (curLayer < 0) curLayer = 0;
    	if (curLayer >= layers.getNumLayers()) curLayer = layers.getNumLayers()-1;

    	if (layers.getNumLayers() > 0) {	
            var poly : Polygon = cast(layers.getLayer(curLayer), Polygon);

            //close loop
	    	var loop = poly.getPoints();
	    	var start = loop[0];
            loop.push(start);

            selectedLayerOutline.setPoints(loop);

            polyCollision = poly.collisionBounds();
    	}
    	else {
	    	selectedLayerOutline.setPoints([]);
    	}
    }

    function addPointToCurrentLine(p:Vector) {
    	curLine.addPoint(p);

    	var test = curLine.getPoints().polylineIntersections();

        if (test.intersects) {

    		var newPolylines = curLine.getPoints().polylineSplit(test.intersectionList[0]);
            var newPolygon = new Polygon({color: curLine.color}, newPolylines.closedLine);
    		
            Edit.AddLayer(layers, newPolygon, curLayer+1);
    		
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

    public function startLayerDrag(mousePos) : Bool {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        if (Collision.pointInPoly(mousePos, polyCollision)) {
            dragMouseStartPos = mousePos;
            return true;
        }
        return false;
    }

    public function layerDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var poly = cast(layers.getLayer(curLayer), Polygon);

        var drag = Vector.Subtract(mousePos, dragMouseStartPos);
        
        poly.transform.pos.add(drag);

        dragMouseStartPos = mousePos;

        switchLayerSelection(0);
    }

    public function startSceneDrag(screenPos) {
        dragMouseStartPos = screenPos;
    }

    public function sceneDrag(screenPos) {
        var drag = Vector.Subtract(dragMouseStartPos, screenPos);
        drag.divideScalar(Luxe.camera.zoom); //necessary b/c I didn't put the vectors into screen space (WHOOPS)

        Luxe.camera.transform.pos.add(drag);

        dragMouseStartPos = screenPos;
    }

    public function undoRedoInput(e:KeyEvent) {
       if (e.keycode == Key.key_z) {
            //Undo
            Edit.Undo();
        }
        else if (e.keycode == Key.key_x) {
            //Redo
            Edit.Redo();
        } 
    }

    public function selectLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_a) {
            //Go up a layer
            switchLayerSelection(-1);
        }
        else if (e.keycode == Key.key_s) {
            //Go down a layer
            switchLayerSelection(1);
        }
    }

    public function deleteLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_p) {  
            //Delete selected layer
            if (layers.getNumLayers() > 0) {    
                Edit.RemoveLayer(layers, curLayer);
                switchLayerSelection(-1);
            }
        }
    }

    public function duplicateLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_d) {
            if (layers.getNumLayers() > 0) {    
                var layerDupe = new Polygon({}, [], cast(layers.getLayer(curLayer), Polygon).getJsonRepresentation());
                layerDupe.transform.pos.add(new Vector(10,10));
                Edit.AddLayer(layers, layerDupe, curLayer);
                switchLayerSelection(1);
            }
        }
    }

    public function moveLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_q) {
            //Move selected layer down the stack
            if (curLayer > 0) {
                Edit.MoveLayer(layers, curLayer, -1);
                switchLayerSelection(-1);
            }
        }
        else if (e.keycode == Key.key_w) {
            //Move selected layer up the stack
            if (curLayer < layers.getNumLayers() - 1) {
                Edit.MoveLayer(layers, curLayer, 1);    
                switchLayerSelection(1);
            }
        }
    }

    public function recentColorsInput(e:KeyEvent) {
        if (e.keycode == Key.key_j) {
            //prev color
            navigateColorList(-1);
        }
        else if (e.keycode == Key.key_k) {
            //next color
            navigateColorList(1);
        }    
    }

    public function colorDropperInput(e:KeyEvent) {
        if (e.keycode == Key.key_m) {
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
    }

    public function saveLoadInput(e:KeyEvent) {
        if (e.keycode == Key.key_1) {
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
    }

    public function zoomInput(e:KeyEvent) {
        if (e.keycode == Key.minus) {
            //zoom out
            Luxe.renderer.camera.zoom *= 0.5;
        }
        else if (e.keycode == Key.equals) {
            //zoom in
            Luxe.renderer.camera.zoom *= 2;
        }
    }

    public function startDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        curLine = new Polyline({color: picker.pickedColor.clone(), depth: aboveLayersDepth+1}, [mousepos]);
        isDrawing = true;
    }

    public function smoothDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        if (isDrawing && Luxe.input.mousedown(1)) {
            if (curLine.getEndPoint().distance(mousepos) >= (minLineLength / Luxe.camera.zoom)) {
                addPointToCurrentLine(mousepos);
            }
        }
    }

    public function pointDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        addPointToCurrentLine(mousepos);
    }

    public function exitColorPickerMode() {
        if (picker.pickedColor != colorList[colorList.length-1]) {
            addColorToList(picker.pickedColor);
        }
        colorPickerMode(false);
    }

    public function enterColorPickerMode() {
        colorPickerMode(true);
    }

    function scaleHandles() {
        var p = curPoly();
        var b = p.getBounds();

        var upPos = Vector.Add( p.transform.pos, p.transform.up().multiplyScalar(b.h * 0.7) );
        var rightPos = Vector.Add( p.transform.pos, p.transform.right().multiplyScalar(b.w * 0.7) );

        var handleSize = 10 / Luxe.camera.zoom;

        return {size: handleSize, up: upPos, right: rightPos};
    }

    public function drawScaleHandles() {
        
        //curPoly().rotation_z += 0.1;
        //curPoly().transform.rotate(0.01);

        var handles = scaleHandles();

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.up,
            color : new Color(255,255,255),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.box({
            x : handles.up.x - (handles.size / 2),
            y : handles.up.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(255,255,255),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.right,
            color : new Color(255,255,255),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.box({
            x : handles.right.x - (handles.size / 2),
            y : handles.right.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(255,255,255),
            depth : aboveLayersDepth,
            immediate : true
        });
    }

    function collisionWithScaleHandle(mousePos) : Bool {

        var handles = scaleHandles();

        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var mouseCollider = new CollisionCircle(mousePos.x, mousePos.y, 5);
        var handleColliderUp = new CollisionCircle(handles.up.x, handles.up.y, handles.size * 0.7); //this collision circle is kind of a hack, but it should be "close enough"
        var handleColliderRight = new CollisionCircle(handles.right.x, handles.right.y, handles.size * 0.7);


        if (Collision.test(mouseCollider, handleColliderUp) != null) {
            scaleDir = curPoly().transform.up();
            return true;
        }
        else if (Collision.test(mouseCollider, handleColliderRight) != null) {
            scaleDir = curPoly().transform.right();
            return true;
        }
        else {
            return false;
        }
    }

    public function startScaleDrag(mousePos) : Bool {
        if (collisionWithScaleHandle(mousePos)) {
            dragMouseStartPos = Luxe.camera.screen_point_to_world(mousePos);
            return true;
        }
        return false;
    }

    //THIS SUCKS -- RETHINK IT LATER
    public function scaleDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        var drag = Vector.Multiply(scaleDir, drag.dot(scaleDir));

        /*
        var scaleFactor = curPoly().transform.scale.toWorldSpace(curPoly().transform);

        trace(scaleFactor);

        drag.divide(scaleFactor);

        trace(drag);
        */

        //curPoly().transform.scale.add(drag.toLocalSpace(curPoly().transform));
        trace(curPoly().transform.scale);
        trace((new Vector(0.00001, 0)).toLocalSpace(curPoly().transform));
        trace((new Vector(0.00001, 0)).toWorldSpace(curPoly().transform));
        curPoly().transform.scale.add( (new Vector(0.00001, 0.00)).toLocalSpace(curPoly().transform) );

        dragMouseStartPos = mousePos;

        switchLayerSelection(0); //hack (probably a better way to do this w/ listening?)

        /*
        var b = curPoly().getBounds();

        drag.multiply(scaleDragAnchor);

        var scalePercent = new Vector(drag.x / b.w, drag.y / b.h);

        curPoly().transform.scale.add(scalePercent);

        dragMouseStartPos = mousePos;

        switchLayerSelection(0); //hack (probably a better way to do this w/ listening?)
        */
    }

    public function drawVertexHandles() {
        if (!areVerticesTooCloseToHandle()) {  
            for (p in curPoly().getPoints()) {
                Luxe.draw.circle({
                    r : 10 / Luxe.camera.zoom,
                    steps: 360,
                    color : new Color(255,255,255),
                    depth : aboveLayersDepth,
                    x : p.x,
                    y : p.y,
                    immediate : true
                });
            }
        }
    }

    function collisionWithVertexHandle(mousePos) : Int {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        
        var vertexCollider = new CollisionCircle(0, 0, 10 / Luxe.camera.zoom);
        var mouseCollider = new CollisionCircle(mousePos.x, mousePos.y, 5);

        var i = 0;
        for (p in curPoly().getPoints()) {
            vertexCollider.x = p.x;
            vertexCollider.y = p.y;

            if (Collision.test(mouseCollider, vertexCollider) != null) {
                return i;
            }

            i++;
        }

        return -1;
    }

    public function startVertexDrag(mousePos) : Bool {
        if (!areVerticesTooCloseToHandle()) {  
            selectedVertex = collisionWithVertexHandle(mousePos);

            if (selectedVertex > -1) {
                dragMouseStartPos = Luxe.camera.screen_point_to_world(mousePos);
                return true;
            }
        }
        return false;
    }

    public function vertexDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        var points = curPoly().getPoints();
        points[selectedVertex].add(drag);
        switchLayerSelection(0);

        curPoly().setPoints(points);

        dragMouseStartPos = mousePos;
    }

    function areVerticesTooCloseToHandle() {
        var points = curPoly().getPoints();
        for (i in 0 ... points.length-1) {
            var p1 = points[i];

            for (j in i+1 ... points.length) {
                var p2 = points[j];

                if (p1.distance(p2) < 10 / Luxe.camera.zoom) {
                    return true;
                }
            }
        }

        return false;
    }

    function curPoly() : Polygon {
        return cast(layers.getLayer(curLayer), Polygon);
    }

} //Main

class DrawState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function onkeydown(e:KeyEvent) {
        //input
        main.undoRedoInput(e);

        main.selectLayerInput(e);

        main.deleteLayerInput(e);

        main.moveLayerInput(e);

        main.duplicateLayerInput(e);

        main.recentColorsInput(e);

        main.colorDropperInput(e);

        main.saveLoadInput(e);

        main.zoomInput(e);
        
        //switch modes
        if (e.keycode == Key.key_l) {
            //enter color picker mode
            machine.set("pickcolor", main);
        }
        
        if (e.keycode == Key.key_e) {
            machine.set("edit", main);
        }
    }

    override function onmousedown(e:MouseEvent) {
        if (!main.isDrawing) {
            main.startDrawing(e);
        }
        else {
            main.pointDrawing(e);
        }
    }

    override function onmousemove(e:MouseEvent) {
        main.smoothDrawing(e);
    }
}

class EditState extends State {

    var main : Main;
    var draggingLayer : Bool;
    var draggingVertex : Bool;
    var draggingScale : Bool;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {
        main.drawScaleHandles();
        main.drawVertexHandles();
    }

    override function onmousedown(e:MouseEvent) {

        draggingScale = main.startScaleDrag(e.pos);

        if (!draggingScale) {
            draggingVertex = main.startVertexDrag(e.pos);
        }

        if (!draggingVertex) {
            draggingLayer = main.startLayerDrag(e.pos);
        }
        
        if (!draggingLayer && !draggingVertex) {
          main.startSceneDrag(e.pos);
        }
    }

    override function onmousemove(e:MouseEvent) {
        if (Luxe.input.mousedown(1)) {
            if (draggingScale) {
                main.scaleDrag(e.pos);
            }
            else if (draggingVertex) {
                main.vertexDrag(e.pos);
            }
            else if (draggingLayer) {
                main.layerDrag(e.pos);
            }
            else {
                main.sceneDrag(e.pos);
            }
        }
    }

    override function onmouseup(e:MouseEvent) {
        draggingVertex = false;
        draggingLayer = false;
    }

    override function onkeydown(e:KeyEvent) {
        //input
        main.undoRedoInput(e);

        main.selectLayerInput(e);

        main.deleteLayerInput(e);

        main.moveLayerInput(e);

        main.duplicateLayerInput(e);

        /*
        main.recentColorsInput(e);

        main.colorDropperInput(e);
        */

        main.saveLoadInput(e);

        main.zoomInput(e);

        //return to draw mode
        if (e.keycode == Key.key_e) {
            machine.set("draw", main);
        }
    }
}

class PickColorState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
        main.exitColorPickerMode();
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
        main.enterColorPickerMode();
    } //onenter

    override function onkeydown(e:KeyEvent) {
        main.recentColorsInput(e);

        main.saveLoadInput(e);

        if (e.keycode == Key.key_l) {
            //leave color picker mode
            machine.set("draw", main);
        }
    }
}   