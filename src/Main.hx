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
import luxe.collision.ShapeDrawerLuxe;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;

import luxe.utils.Maths;
import snow.types.Types;
import luxe.Entity;
import luxe.Camera;
import luxe.Scene;

//HAXE
//IOS hack

import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;


//ARL
/*
import Polyline;
import Polygon;
import ColorPicker;
import Slider;
import Edit;
import LayerManager;
*/
import animation.Bone;
import components.Animation;
import components.PuppetAnimation;

using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.PolylineExtender;
using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.FileInputExtender;
import ledoux.UtilityBelt.DynamicExtender;

class Main extends luxe.Game {

    //singleton
    public static var instance : Main;

	//drawing
	var curLine : Polyline;
	var minLineLength = 20;
	public var isDrawing : Bool;

	//layers
	public var layers = new LayerManager(0, 1, 1000);
	var aboveLayersDepth = 10001;
	var curLayer = 0;
	public var selectedLayerOutline : Polyline;

	//color picker
	var picker : ColorPicker;
	var slider : Slider;
	var curColorIcon : QuadGeometry;
	var colorList : Array<ColorHSV> = [];
	var colorIndex : Int;

    //editting
    var dragMouseStartPos : Vector;
    var selectedVertex : Int;
    var scaleDirLocal : Vector;
    var scaleDirWorld : Vector;

    //ui
    public var uiBatcher : Batcher; //old ui
    //main ui
    public var uiSceneBatcher : Batcher; //batcher for the JSON scene
    public var uiSceneCamera : Camera;
    public var uiScene : Scene;
    //play mode ui
    public var playModeUIBatcher : Batcher;
    public var playModeUICamera : Camera;
    public var playModeUIScene : Scene;

    //states
    public var machine : States;

    //collisions
    var polyCollision : CollisionPoly;

    //play mode and components
    public var componentManager = new ComponentManager();

    //camera and zoom
    var refSize = new Vector(960, 640);

    //animation
    public var boneBatcher : Batcher;

    override function ready() {
        instance = this;

        trace(Luxe.screen.size);
        trace(Luxe.camera.center);
        trace(Luxe.screen.mid);

    	//instantiate objects
        selectedLayerOutline = new Polyline({depth: aboveLayersDepth}, []);

        //render settings
        Luxe.renderer.batcher.layer = 1;
        Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.2);
        Luxe.renderer.state.lineWidth(2);

        //UI
        createUI();
        boneBatcher = Luxe.renderer.create_batcher({name:"boneBatcher", layer:2, camera:Luxe.camera.view});  

        //STATES
        machine = new States({name:"statemachine"});
        machine.add(new DrawState({name:"draw"}));
        machine.add(new PickColorState({name:"pickcolor"}));
        machine.add(new EditState({name:"edit"}));
        machine.add(new AnimationState({name:"animation"}));
        machine.add(new PlayState({name:"play"}));
        machine.add(new GroupState({name:"group"}));
        machine.add(new ComponentState({name:"component"}));
        machine.set("draw", this);

        //HACK TO LOAD TEST LEVEL IMMEDIATELY
        /*
        Luxe.loadJSON("assets/prototype5.json", function(j) {
            var inObj = j.json;

            for (l in cast(inObj.layers, Array<Dynamic>)) {
                Edit.AddLayer(layers, new Polygon({}, [], l), curLayer+1);
                switchLayerSelection(1);
            }

            Luxe.loadJSON("assets/prototype5_components.json", function(j) {
                var inObj = j.json;
                componentManager.updateFromJson(inObj);

                machine.set("play", this);
            });
        });
        */

       // new IconButton({}, "/Users/adamrossledoux/Code/Haxe/LuxePolygonDraw/levels/floppy_icon.json");

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

    override function onwindowresized(e:WindowEvent) {
        //Luxe.camera.viewport.w = e.event.x;
        //Luxe.camera.viewport.h = e.event.y;
        
        //trace(e.event.x);
        //trace(Luxe.screen.w);
        //trace(Luxe.camera.pos);


        var tmp = Luxe.camera.center.clone();
        Luxe.camera.size = Luxe.screen.size.clone();
        trace(Luxe.screen.mid);
        trace(Luxe.camera.center);
        //Luxe.camera.center = tmp;
        trace(Luxe.camera.center);

        

        Luxe.camera.zoom = Luxe.screen.size.y / refSize.y;
        Luxe.camera.pos = Vector.Subtract(Luxe.screen.size, Vector.Multiply(refSize, 1 / Luxe.camera.zoom));


        //trace(Luxe.camera.viewport);
        //Luxe.camera.center = Luxe.screen.mid.clone();
    }

    function createUI () {
        //separate batcher to layer UI over drawing space
        uiBatcher = Luxe.renderer.create_batcher({name:"uiBatcher", layer:10});

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


        //// NEW UI FROM JSON
        uiScene = new Scene("uiScene");
        uiSceneCamera = new Camera({name:"uiSceneCamera", scene: uiScene});
        uiSceneBatcher = Luxe.renderer.create_batcher({name: "uiSceneBatcher", layer: 11, camera: uiSceneCamera.view});
        
          
        Luxe.loadJSON("assets/ui/ed_ui_scene9.json", function(j) {

            DynamicExtender.jsonToScene(j.json, uiSceneBatcher, uiScene);

            //TODO
            Luxe.loadJSON("assets/ui/ed_ui_scene9_components.json", function(j) {
                componentManager.updateFromJson(j.json);
                componentManager.activateComponents(uiScene);
            });

        });
        

        playModeUIScene = new Scene("playModeUIScene");
        playModeUICamera = new Camera({name:"playModeUICamera", scene: playModeUIScene});
        playModeUIBatcher = Luxe.renderer.create_batcher({name: "playModeUIBatcher", layer: 11, camera: playModeUICamera.view});

        Luxe.loadJSON("assets/ui/play_ui_scene2.json", function(j) {

            DynamicExtender.jsonToScene(j.json, playModeUIBatcher, playModeUIScene);

            //TODO
            Luxe.loadJSON("assets/ui/play_ui_scene2_components.json", function(j) {
                componentManager.updateFromJson(j.json);

                Luxe.renderer.remove_batch(playModeUIBatcher); //make it invisible
            });

        });
        
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
        
        //poly.transform.pos.add(drag);
        poly.pos.add(drag);

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

    public function Undo() {
        Edit.Undo();
    }

    public function Redo() {
        Edit.Redo();
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
                var layerDupe = new Polygon({}, [], cast(layers.getLayer(curLayer), Polygon).jsonRepresentation());
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

    public function addCircleInput(e:KeyEvent) {
        if (e.keycode == Key.key_t) {
            var worldMousePos = Luxe.camera.screen_point_to_world(Luxe.screen.cursor.pos);
            var points : Array<Vector> = [];
            points = points.makeCirclePolyline(worldMousePos, (Luxe.screen.w / 50) / Luxe.camera.zoom);

            trace(points);

            //var newPLine = new Polyline({color: picker.color}, points);
            var newPolygon = new Polygon({color: curColorIcon.color.clone()}, points);
            Edit.AddLayer(layers, newPolygon, curLayer+1);
            switchLayerSelection(1);
        }
    }

    public function saveLoadInput(e:KeyEvent) {

        //HACK for ios
        
        if (e.keycode == Key.key_1) {
            Save();
        }
        else if (e.keycode == Key.key_2) {
            Load();
        }
        
    }

    public function Save() {
        //save
        var rawSaveFileName = Luxe.core.app.io.platform.dialog_save().split(".");
        var saveFileName = rawSaveFileName[0];

        //scene file
        var output = File.write(saveFileName + ".json", false);

        var outObj = layers.jsonRepresentation();
        var outStr = haxe.Json.stringify(outObj);
        output.writeString(outStr);

        output.close();

        //component file
        var output = File.write(saveFileName + "_components.json", false);

        var outObj = componentManager.jsonRepresentation();
        var outStr = haxe.Json.stringify(outObj, null, "    ");
        output.writeString(outStr);

        output.close();

    }

    public function Load() {
        //load
        var rawOpenFileName = Luxe.core.app.io.platform.dialog_open().split(".");
        var openFileName = rawOpenFileName[0];

        trace("file " + openFileName);

        //scene file
        var input = File.read(openFileName + ".json", false);

        var polys = input.readScene(Luxe.renderer.batcher, Luxe.scene);

        //TODO - rewrite the layer manager
        for (p in polys) {
            Edit.AddLayer(layers, p, curLayer+1);
            switchLayerSelection(1);
        }
        

        input.close();

        //component file
        var input = File.read(openFileName + "_components.json", false);

        //read all - regardless of how many lines it is
        var inStr = "";
        while (!input.eof()) {
            inStr += input.readLine();
        }

        var inObj = haxe.Json.parse(inStr);

        componentManager.updateFromJson(inObj);

        input.close();
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
        if (e.pos.x < Luxe.screen.w * 0.85) { //HORRIBLE HACKS

            var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
            curLine = new Polyline({color: picker.pickedColor.clone(), depth: aboveLayersDepth+1}, [mousepos]);
            isDrawing = true;
        }
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

    public function drawRotationHandle() {

        var p = curPoly();
        var b = p.getRectBounds();
        var handlePos = Vector.Subtract( p.transform.pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handlePos,
            color : new Color(255,0,255),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.ring({
            x : handlePos.x,
            y : handlePos.y,
            r : (15 / Luxe.camera.zoom),
            color : new Color(255,0,255),
            depth : aboveLayersDepth,
            immediate : true
        });
    }

    public function startRotationDrag(mousePos : Vector) : Bool {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var p = curPoly();
        var b = p.getRectBounds();
        var handlePos = Vector.Subtract( p.transform.pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        if (mousePos.distance(handlePos) < (15 / Luxe.camera.zoom)) {
            return true;
        }

        return false;
    }

    public function rotationDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var p = curPoly();

        var rotationDir = Vector.Subtract(mousePos, p.transform.pos);
        p.rotation_z = Maths.degrees(rotationDir.angle2D) - 90 - (p.transform.scale.y > 0 ? 180 : 0); // - 270;

        switchLayerSelection(0);
    }

    function scaleHandles() {
        var p = curPoly();
        var b = p.getRectBounds();

        var upPos = Vector.Add( p.transform.pos, p.transform.up().multiplyScalar(b.h * 0.7 /* * 0.5 */ /* * 0.7 */) );
        var rightPos = Vector.Add( p.transform.pos, p.transform.right().multiplyScalar(b.w * 0.7 /* * 0.5 */ /* * 0.7 */) );

        var handleSize = 10 / Luxe.camera.zoom;

        return {size: handleSize, up: upPos, right: rightPos};
    }

    public function drawScaleHandles() {
        var handles = scaleHandles();

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.up,
            color : new Color(0,255,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.rectangle({
            x : handles.up.x - (handles.size / 2),
            y : handles.up.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(0,255,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.right,
            color : new Color(255,0,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.rectangle({
            x : handles.right.x - (handles.size / 2),
            y : handles.right.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(255,0,0),
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
            scaleDirLocal = new Vector(0,1); // NOT A GREAT WAY TO DO THIS
            //scaleDirWorld = curPoly().transform.up();
            return true;
        }
        else if (Collision.test(mouseCollider, handleColliderRight) != null) {
            scaleDirLocal = new Vector(1,0);
            //scaleDirWorld = curPoly().transform.right();
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

    //this mostly works (but could be better)
    public function scaleDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        if (scaleDirLocal.x != 0) {
            scaleDirWorld = curPoly().transform.right();
        }
        else {
            scaleDirWorld = curPoly().transform.up();
        }

        var scaleDelta = Vector.Multiply(scaleDirLocal, drag.dot(scaleDirWorld));
        scaleDelta.x = (scaleDelta.x / curPoly().getRectBounds().w) * curPoly().transform.scale.x * 2;
        scaleDelta.y = (scaleDelta.y / curPoly().getRectBounds().h) * curPoly().transform.scale.y * 2;

        curPoly().transform.scale.add(scaleDelta);

        //hack to avoid the horrible problems that occur when scale == 0
        if (curPoly().transform.scale.x == 0) {
            curPoly().transform.scale.x = 0.01;
        }
        if (curPoly().transform.scale.y == 0) {
            curPoly().transform.scale.y = 0.01;
        }

        dragMouseStartPos = mousePos;

        switchLayerSelection(0); //hack (probably a better way to do this w/ listening?)
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

    public function curPoly() : Polygon {
        return cast(layers.getLayer(curLayer), Polygon);
    }

    public function enterPlayMode() {
        componentManager.activateComponents();

        Luxe.renderer.add_batch(playModeUIBatcher);
        componentManager.activateComponents(playModeUIScene);
    }

    public function exitPlayMode() {
        componentManager.deactivateComponents();

        Luxe.renderer.remove_batch(playModeUIBatcher);
        componentManager.deactivateComponents(playModeUIScene);
    }

    public function addSelectedLayerToComponentManagerInput(e : KeyEvent) {
        //HACK IOS
        
        if (e.keycode == Key.key_c) {
            //load
            var rawOpenFileName = Luxe.core.app.io.platform.dialog_open( "Load Component", [{extension:"hx"}] ).split(".");
            var openFileName = rawOpenFileName[0];
            var fileNameSplit = openFileName.split("/"); //need to change for other OSs?
            var className = fileNameSplit[fileNameSplit.length-1];
            componentManager.addComponent(curPoly(), className);
        }
        
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

        main.addSelectedLayerToComponentManagerInput(e);

        main.addCircleInput(e);
        
        //switch modes
        if (e.keycode == Key.key_v) {
            machine.set("component", main);
        }

        if (e.keycode == Key.key_l) {
            //enter color picker mode
            machine.set("pickcolor", main);
        }
        
        if (e.keycode == Key.key_e) {
            machine.set("edit", main);
        }

        if (e.keycode == Key.key_0) {
            machine.set("play", main);
        }

        if (e.keycode == Key.key_b) {
            machine.set("animation", main);
        }

        if (e.keycode == Key.key_g) {
            machine.set("group", main);
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
    var draggingRotation : Bool;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {
        main.drawScaleHandles();
        main.drawRotationHandle();
        main.drawVertexHandles();
    }

    override function onmousedown(e:MouseEvent) {

        draggingScale = main.startScaleDrag(e.pos);

        if (!draggingScale) {
            draggingRotation = main.startRotationDrag(e.pos);
        }

        if (!draggingRotation) {
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
            else if (draggingRotation) {
                main.rotationDrag(e.pos);
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
        draggingRotation = false;
        draggingScale = false;
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

class AnimationState extends State {
    var main : Main;

    //bones
    var boneArray : Array<Bone> = [];
    var selectedBone : Bone;

    //making a new bone
    var startPos : Vector;
    var endPos : Vector;

    //modes
    var isMakingBone : Bool; 
    var isRotatingBone : Bool;   

    //debug
    var drawer : ShapeDrawerLuxe = new ShapeDrawerLuxe();

    //
    var curFrame : Int = 0;

    function updateBoneArray() {
        boneArray = [];

        var rootBones : Array<Entity> = [];
        Luxe.scene.get_named_like("Bone.*", rootBones); //find root bones

        for (b in rootBones) {
            var root = cast b;
            boneArray = boneArray.concat(root.skeleton());
        }
    }

    override function init() {
    } //init

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onmousedown(e:MouseEvent) {
        updateBoneArray();

        var worldMousePos = Luxe.camera.screen_point_to_world(e.pos);
        var mouseCollisionShape = new CollisionCircle(worldMousePos.x, worldMousePos.y, 10);

        if (selectedBone != null) {
            if (Collision.test(mouseCollisionShape, selectedBone.rotationHandleCollisionShape()) != null) {
                isRotatingBone = true;
            }
        }

        if (!isRotatingBone) {

            isMakingBone = true;
            for (b in boneArray) {
                //var bone = cast(b, Bone); //cast to bone
                if (Collision.test(mouseCollisionShape, b.collisionShape()) != null) {
                    selectBone(b);
                    isMakingBone = false;
                    break;
                }
            }

            if (isMakingBone) {
                startPos = Luxe.camera.screen_point_to_world(e.pos);
                endPos = startPos.clone(); 
            }

        }
        
    }

    override function onmousemove(e:MouseEvent) {
        if (Luxe.input.mousedown(1)) {
            if (isMakingBone) {
                endPos = Luxe.camera.screen_point_to_world(e.pos);
            }
            else if (isRotatingBone) {
                selectedBone.rotation_z = Maths.degrees( Luxe.camera.screen_point_to_world(e.pos).subtract(selectedBone.worldPos()).angle2D );
                selectedBone.rotation_z += 90;
                //surely there must be a better way to do this? why isn't this all automatic?
                if (selectedBone.parent != null) {
                    selectedBone.rotation_z = selectedBone.parent.transform.worldRotationToLocalRotationZ(selectedBone.rotation_z);
                }
            }
        }
    }

    override function onmouseup(e:MouseEvent) {
       
       if (isMakingBone) {
            if (selectedBone != null) {

                var b = new Bone({
                        pos : startPos.toLocalSpace(selectedBone.transform), 
                        parent : selectedBone,
                        batcher : main.boneBatcher
                    }, 
                    startPos.distance(endPos),
                    selectedBone.transform.worldRotationToLocalRotationZ( Maths.degrees(endPos.clone().subtract(startPos).angle2D) - 90 )
                );
                
                selectBone(b);
            }
            else {

                var b = new Bone({
                        pos : startPos, 
                        batcher : main.boneBatcher
                    }, 
                    startPos.distance(endPos), 
                    Maths.degrees(endPos.clone().subtract(startPos).angle2D) - 90
                );

                selectBone(b);
            }
        }
        
        isMakingBone = false;
        isRotatingBone = false;
    }

    override function update(dt:Float) {
        updateBoneArray();

        if (selectedBone != null) selectedBone.drawEditHandles();

        if (isMakingBone) {
            Luxe.draw.line({
                p0 : startPos,
                p1 : endPos,
                color : new Color(255,255,0),
                immediate : true,
                batcher : main.uiBatcher
            });
        }

        Luxe.draw.text({
            color: new Color(255,255,255),
            pos : new Vector(Luxe.screen.mid.x, 30),
            point_size : 20,
            text : "Frame: " + curFrame,
            immediate : true,
            batcher : main.uiBatcher
        });

    }

    override function onkeydown(e:KeyEvent) {

        main.selectLayerInput(e);

        if (boneArray.length > 0) {
            var skeletonRoot = boneArray[0];

            if (e.keycode == Key.equals) {
                curFrame++;
                skeletonRoot.frameIndex = curFrame;
            }
            else  if (e.keycode == Key.minus) {
                curFrame--;
                skeletonRoot.frameIndex = curFrame;
            }

            curFrame = skeletonRoot.frameIndex; //make sure we don't get a mismatch or go out of bounds

            if (e.keycode == Key.key_a) {
                skeletonRoot.animate(1);
            }
        }

        if (selectedBone != null) {
            if (e.keycode == Key.key_p) { //delete selected bone

                var tmp = selectedBone;

                //find new bone to select if possible
                if (selectedBone.parent != null) {
                    selectBone(cast selectedBone.parent);
                }
                else {
                    selectedBone = null;
                }
                
                tmp.destroy(); 
            }
        }
        

        if (e.keycode == Key.key_i) {
            Luxe.renderer.remove_batch(main.boneBatcher);
        }
        else if (e.keycode == Key.key_u) {
            Luxe.renderer.add_batch(main.boneBatcher);
        }

        if (e.keycode == Key.key_g) { //attach skeleton to poly
            main.curPoly().add(new Animation({name: "Animation"}));
            cast(main.curPoly().get("Animation"), Animation).skeletonRoot = boneArray[0];
        }

        if (e.keycode == Key.key_h) { //attach selected bone to selected poly (1:1)
            main.curPoly().add(new PuppetAnimation({name: "PuppetAnimation"}));
            cast(main.curPoly().get("PuppetAnimation"), PuppetAnimation).bone = selectedBone;
            //WORK IN PROGRESS
            //cast(main.curPoly().get("PuppetAnimation"), PuppetAnimation).boneName = selectedBone.name;
        }

        if (e.keycode == Key.key_b) {
            //leave animation mode
            machine.set("draw", main);
        }
    } 

    function selectBone(b : Bone) {
        if (selectedBone != null) {
            selectedBone.color = new Color(255,255,255);
        }
        selectedBone = b;
        selectedBone.color = new Color(255,255,0);
    }
}

class PlayState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
        main.exitPlayMode();

        //HACK
        Luxe.renderer.add_batch(main.uiBatcher);
        Luxe.renderer.add_batch(main.uiSceneBatcher);
        Luxe.renderer.batcher.add(main.selectedLayerOutline.geometry);
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
        main.enterPlayMode();

        //HACK
        Luxe.renderer.remove_batch(main.uiBatcher);
        Luxe.renderer.remove_batch(main.uiSceneBatcher);
        Luxe.renderer.batcher.remove(main.selectedLayerOutline.geometry); 
    } //onenter

    override function onkeydown(e:KeyEvent) {
        if (e.keycode == Key.key_0) {
            //leave play mode
            machine.set("draw", main);
        }
    }    
} 


class ComponentState extends State {
    var main : Main;

    var curEntry : Dynamic;

    var addCollisionBounds : CollisionPoly = new CollisionPoly(0,0,[new Vector(0,0), new Vector(0,0), new Vector(0,0)]);
    var removeComponentCollisionBoxes : Array<CollisionPoly> = [];

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {
        
        if (main.curPoly() != null) {

            //get data about selected object
            curEntry = main.componentManager.getEntry(main.curPoly());
        
            var numComponents = 0;
            if (curEntry != null) {
                numComponents = curEntry.components.length;
            }

            var componentNames = [];
            if (curEntry != null) {
                for (c in cast(curEntry.components, Array<Dynamic>)) {
                    componentNames.push(c.name);
                }
                //trace(componentNames);
            }

            //draw component # box
            Luxe.draw.box({
                x : -Luxe.camera.pos.x + main.curPoly().pos.x - 20,
                y : -Luxe.camera.pos.y + main.curPoly().pos.y - 10,
                w : 60,
                h : 30,
                batcher: main.uiBatcher,
                immediate : true,
                color : new Color(255, 255, 255)
            });

            Luxe.draw.rectangle({
                x : -Luxe.camera.pos.x + main.curPoly().pos.x - 20,
                y : -Luxe.camera.pos.y + main.curPoly().pos.y - 10,
                w : 60,
                h : 30,
                batcher: main.uiBatcher,
                immediate : true,
                color : new Color(0, 0, 0)
            });

            Luxe.draw.text({
                color: new Color(0,0,0),
                pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x - 10, 
                    -Luxe.camera.pos.y + main.curPoly().pos.y - 10),
                point_size : 20,
                text : "c: " + numComponents,
                immediate : true,
                batcher : main.uiBatcher
            });

            //draw component box
            var r = main.curPoly().getRectBounds();
            var h = 10 + (numComponents+1) * 20;
            Luxe.draw.box({
                x: -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20,
                y: -Luxe.camera.pos.y + main.curPoly().pos.y - h/2,
                w : 220,
                h : h,
                immediate : true,
                color : new Color(1,1,1),
                batcher : main.uiBatcher
            });

            //write component names
            var i = 0;
            removeComponentCollisionBoxes = []; //hacky ass way to do this shit <3 <3 <3
            for (cName in componentNames) {
                Luxe.draw.text({
                    color: new Color(0,0,0),
                    pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 40, 
                        -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                    point_size : 20,
                    text : cName,
                    immediate : true,
                    batcher : main.uiBatcher
                });

                Luxe.draw.text({
                    color: new Color(1,0,0),
                    pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20, 
                        -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                    point_size : 20,
                    text : "X",
                    immediate : true,
                    batcher : main.uiBatcher
                });

                var x = -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20;
                var y = -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20);
                var w = 20;
                var h = 20;
                removeComponentCollisionBoxes.push( 
                                        new CollisionPoly(0,0,
                                                [new Vector(x,y), new Vector(x+w,y),
                                                    new Vector(x+w,y+h), new Vector(x,y+h)])); //wtf is this formating le doux <3

                
                i++;
            }

            //add component text
            Luxe.draw.text({
                color: new Color(0,1,0),
                pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20, 
                    -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                point_size : 20,
                text : "+ Add Component",
                immediate : true,
                batcher : main.uiBatcher
            });

            //update collision box
            var x = -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20;
            var y = -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20);
            var w = 200;
            var h = 20;
            addCollisionBounds = new CollisionPoly(0,0,[new Vector(x,y), new Vector(x+w,y),
                                        new Vector(x+w,y+h), new Vector(x,y+h)]);
        }
        
    }

    override function onkeydown(e:KeyEvent) {
        main.selectLayerInput(e);

        main.addSelectedLayerToComponentManagerInput(e);

        if (e.keycode == Key.key_v) {
            machine.set("draw", main);
        }
    }

    override function onmousedown(e:MouseEvent) {
        if (Collision.pointInPoly(e.pos, addCollisionBounds)) {
            //load
            var rawOpenFileName = Luxe.core.app.io.platform.dialog_open( "Load Component", [{extension:"hx"}] ).split(".");
            var openFileName = rawOpenFileName[0];
            var fileNameSplit = openFileName.split("/"); //need to change for other OSs?
            var className = fileNameSplit[fileNameSplit.length-1];
            main.componentManager.addComponent(main.curPoly(), className);
        }

        for (i in 0 ... removeComponentCollisionBoxes.length) {
            trace("remove comp " + i + "??");

            var rccb = removeComponentCollisionBoxes[i];
            var comp = curEntry.components[i];

            if (Collision.pointInPoly(e.pos, rccb)) {
                trace("kill dat shit");
                curEntry.components.remove(comp);
            }
        }
    }
}

class GroupState extends State {
    var startGroupPos = new Vector(0,0);
    var endGroupPos = new Vector(0,0);
    var isGrouping = false;

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {
        Luxe.draw.rectangle({
            x : startGroupPos.x,
            y : startGroupPos.y,
            w : endGroupPos.x - startGroupPos.x,
            h : endGroupPos.y - startGroupPos.y,
            depth: 1000,
            immediate : true,
            color : new Color(255, 255, 0)
        });
    }

    override function onkeydown(e:KeyEvent) {
        if (e.keycode == Key.key_g) {
            machine.set("draw", main);
        }

        if (e.keycode == Key.key_t) {

            //this will contain all the polygons that are being grouped together
            var polysInGroup = [];

            //this represents the space highlighted by the cursor for grouping
            var groupCollisionArea = new CollisionPoly(0, 0, 
                [
                    startGroupPos, 
                    new Vector(endGroupPos.x, startGroupPos.y),
                    endGroupPos,
                    new Vector(startGroupPos.x, endGroupPos.y)
                ]
            );

            //detect collisions between highlighted area and polygongs
            for (v in main.layers.layers) {
                var poly = cast(v, Polygon);
                if (Collision.test(groupCollisionArea, poly.collisionBounds()) != null) {
                    polysInGroup.push(poly);
                }
            }

            //remove polys from layer manager, and add them as children to new parent polygon
            //var c = new Vector(0,0);
            if (polysInGroup.length > 0) {
                var parentPoly = new Polygon({}, []);

                /*
                for (childPoly in polysInGroup) {
                    c.add(childPoly.pos);
                }
                c.divideScalar(polysInGroup.length);
                parentPoly.pos = c;
                */

                for (childPoly in polysInGroup) {
                    main.layers.removeLayer(childPoly);
                    childPoly.parent = parentPoly;
                }

                parentPoly.recenter();

                main.layers.addLayer(parentPoly);
            }
        }
    }

    override function onmousedown(e:MouseEvent) {
        startGroupPos = Vector.Add( Luxe.camera.pos, e.pos );
        endGroupPos = startGroupPos.clone();
        isGrouping = true;
    }

    override function onmousemove(e:MouseEvent) {
        if (isGrouping) endGroupPos = Vector.Add( Luxe.camera.pos, e.pos );
    }

    override function onmouseup(e:MouseEvent) {
        isGrouping = false;
    }
}