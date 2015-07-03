//LUXE
import luxe.Input;
import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher;
import phoenix.Transform;
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
import luxe.Timer;
import luxe.Text;


//HAXE
//IOS hack

import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;

//ARL
import animation.Bone;

import components.Animation;
import components.PuppetAnimation;

using utilities.VectorExtender;
using utilities.PolylineExtender;
using utilities.TransformExtender;
using utilities.FileInputExtender;
using utilities.PolygonGroupExtender;

import states.ComponentState;

class Main extends luxe.Game {

    //singleton
    public static var instance : Main;

	//drawing
	var curLine : Polyline;
	var minLineLength = 20;
	public var isDrawing : Bool;

	//layers
	//public var layers = new LayerManager(0, 1, 1000);
    public var rootLayers : Array<Polygon> = [];
    public var layers : Array<Polygon>;// = [];
	var aboveLayersDepth = 10001;
	public var curLayer = 0;
	public var selectedLayerOutline : Polyline;
    public var localSpace : Transform;
    public var layerStack : Array<Int> = [];

	//color picker
	public var picker : ColorPicker;
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

    //saving
    public var curScenePath : String;
    var autoSaveOn : Bool;

    //undo / redo (v2)
    var doneStack = [];
    var undoneStack = [];

    //fix for camera pos reset problem
    var totalCameraDragDist = new Vector(0,0);

    //new layer ui
    var isLayerNavigatorActive = false;
    var layerNavUpTime = 5; //seconds
    var navUpTimer : Timer = new Timer(Luxe.core);
    var layerNavMode = 0; //0 = select, 1 = move, 2 = group
    var layerGroupLastIndex = 0;


    //new top UI
    var helpText : String;
    var defaultHelpText = "[O]pen, [S]ave, [W/S] Select Layer, [H]elp";
    var helpMsgTimer : Timer = new Timer(Luxe.core);
    public var curModeText : String;
    public var curToolText : String;

    override function ready() {

        instance = this;

        //start current layers on root list
        layers = rootLayers;
        localSpace = null;

        trace(Luxe.screen.size);
        trace(Luxe.camera.center);
        trace(Luxe.screen.mid);

    	//instantiate objects
        selectedLayerOutline = new Polyline({depth: aboveLayersDepth}, []);

        //render settings
        Luxe.renderer.batcher.layer = 1;
        //Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.2); //old color
        //Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.1); //dark grey
        Luxe.renderer.clear_color = new ColorHSV(250, 0.5, 0.3); //blue
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

       //HACK??? - this keeps the screen centered nicely on resize (for SOME REASON??)
       Luxe.camera.size = Luxe.screen.size;

       uiSceneCamera.size = Luxe.screen.size;
       uiSceneCamera.size_mode = SizeMode.contain;

       //set up on automatic saving
       autoSaveOn = true;
       Luxe.timer.schedule(10, function() {
            if (curScenePath != null && autoSaveOn && layers.length > 0) { 
                //don't autosave a blank file, so you don't lose your autosave backup
                trace("SAVING ...");
                setHelpMessage("Saving...");
                SaveAuto(curScenePath);
            } 
        }, true);
       //sys.FileSystem.deleteDirectory("/Users/adamrossledoux/Code/Haxe/LuxePolygonDraw/assets/autosave");
       curScenePath = "/Users/adamrossledoux/Code/Haxe/LuxePolygonDraw/assets/autosave";

       //undo / redo
       layerStack.push(curLayer);
       saveEditorState();

       //
       helpText = defaultHelpText;
    } //ready

    override function onevent(e:SystemEvent) {
        if (e.type == SystemEventType.file) {
            if (e.file.type == FileEventType.modify) {
                if (e.file.path.lastIndexOf("components") != -1) { //is stored in components folder (proabably) hack
                    trace("update component!");

                    var input = File.read(e.file.path, false);

                    //read all - regardless of how many lines it is
                    var inStr = "";
                    while (!input.eof()) {
                        inStr += input.readLine();
                    }

                    var inObj = haxe.Json.parse(inStr);

                    componentManager.updateComponentFromJson(inObj.name, inObj);

                    input.close();
                }
            }
        }
        else if (e.type == SystemEventType.window) {
            //hack for error: snow.types.WindowEventType should be Null<snow.types.WindowEvent>
            if (e.window.type == WindowEventType.focus_lost) {
                autoSaveOn = false;
            }
            else if (e.window.type == WindowEventType.focus_gained) {
                autoSaveOn = true;
            }
        }
    }

    public function groupLayers(startIndex, lastIndex) {
        var groupLayer = cast( Math.min(startIndex, lastIndex), Int );

        var polysInGroup = [];
        var i = 0;
        for (l in layers) {

            
            var isSelectedGroup = ( 
                            ( (lastIndex > startIndex && i <= lastIndex && i >= startIndex) ||
                            (lastIndex < startIndex && i >= lastIndex && i <= startIndex) )
                        );
            

            if (isSelectedGroup) {
                polysInGroup.push(l);
            }

            i++;

        }

        var parentPoly = new Polygon({}, []);

        for (childPoly in polysInGroup) {
            layers.remove(childPoly);
            childPoly.parent = parentPoly;
        }

        parentPoly.recenter();

        if (layers.length > 0 && layers[0].parent != null) {
            var parent = layers[0].parent;
            parentPoly.parent = parent;
        }
        layers.insert(groupLayer, parentPoly);
        rootLayers.setDepthsRecursive(0, 1);
    }

    override function onkeydown(e:KeyEvent) {
        //practice opening files from command line
        /*
        Sys.command("open '/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl'");
        Sys.command("'/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl' ~/Code/Web/egg/index.html");
        */

        if (e.keycode == Key.lshift || e.keycode == Key.rshift) {
            if (isLayerNavigatorActive) {
                layerNavMode = 1; //press shift to engage move mode
            }
        }

        if (e.keycode == Key.lmeta || e.keycode == Key.rmeta) {
            if (isLayerNavigatorActive) {
                if (layerNavMode == 2) {
                    //group and exit group mode
                    if (curLayer != layerGroupLastIndex) {
                        groupLayers(curLayer, layerGroupLastIndex);
                        goToLayer( (curLayer < layerGroupLastIndex) ? curLayer : layerGroupLastIndex );
                        saveEditorState();
                    }
                    layerNavMode = 0; //return to select mode
                }
                else {
                    layerNavMode = 2; //press meta to engage group mode
                }
            }
        }

        if (e.keycode == Key.key_w && e.mod.meta) { //meta == cmd (or Win key?)
            if (layerNavMode != 2) layerGroupLastIndex = curLayer;
            if (layerGroupLastIndex < layers.length - 1) layerGroupLastIndex++;
            activateLayerNavigator(2);
        }
        if (e.keycode == Key.key_s && e.mod.meta) { //meta == cmd (or Win key?)
            if (layerNavMode != 2) layerGroupLastIndex = curLayer;
            if (layerGroupLastIndex > 0) layerGroupLastIndex--;
            activateLayerNavigator(2);
        }

        if (e.keycode == Key.key_w && e.mod.alt) {
            if (curPoly().children.length > 0) { //not foolproof
                editGroup(curPoly());
            }
        }
        if (e.keycode == Key.key_s && e.mod.alt) {
            if (layerStack.length > 1) {
                exitCurrentGroup();
            }
        }

        if (e.keycode == Key.key_u && e.mod.meta) { //ungroup
            if (curPoly().children.length > 0) {
                ungroupLayers(curPoly());
                saveEditorState();
            }
        }
    }

    override function onkeyup(e:KeyEvent) {
        if (e.keycode == Key.key_w || e.keycode == Key.key_s) {
            if (e.mod.shift) {
                saveEditorState(); //enable undo / redo for layer movement
            }
        }

        if (e.keycode == Key.lshift || e.keycode == Key.rshift) {
            if (layerNavMode > 0) {
                layerNavMode = 0; //let go of shift and return to select mode
            }
        }

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }
    } //onkeyup

    override function update(dt:Float) {
        drawGrid();

        curModeText = machine.current_state.name;
        curToolText = "tool select";
        drawHelpText();
        drawSceneName();
        drawPlayPauseText();
        drawModeText();

        //trace(Luxe.screen.mid);
        //trace(Luxe.camera.center);

        if (isLayerNavigatorActive) {
            
            drawLayerNavigator();

            if (Luxe.screen.cursor.pos.x < 50) {

                trace("mouse input");

                activateLayerNavigator(layerNavMode); //keep layer navigator open

                var closestLayer = 0;
                for (i in 0 ... layers.length) {
                    var closeH = uiSceneCamera.size.y * ( 1 - ((closestLayer+1) / (layers.length+1)) );
                    var layerH = uiSceneCamera.size.y * ( 1 - ((i+1) / (layers.length+1)) );

                    if (Math.abs(Luxe.screen.cursor.pos.y - layerH) < Math.abs(Luxe.screen.cursor.pos.y - closeH)) {
                        closestLayer = i;
                    }
                }

                if (layerNavMode == 0) {
                    goToLayer(closestLayer);   
                }
                else if (layerNavMode == 1) {
                    if (curLayer != closestLayer) {

                        //if (closestLayer > curLayer) closestLayer--;

                        var p = curPoly();
                        layers.remove(p);
                        layers.insert(closestLayer, p);

                        goToLayer(closestLayer);
                    }
                }
                else if (layerNavMode == 2) {
                    layerGroupLastIndex = closestLayer;
                }
            }
        }

        if (layers.length <= 0) drawTitle();

        //hack to keep layers up to date
        rootLayers.setDepthsRecursive(0,1);
    } //update

    function drawHelpText() {
         Luxe.draw.text({
            color: new Color(1,1,1),
            pos : new Vector(0,0),
            point_size : 16,
            text : helpText,
            immediate : true,
            batcher : uiSceneBatcher
        });
    }

    public function setHelpMessage(msg) {
        helpText = msg;

        helpMsgTimer.reset();
        helpMsgTimer.schedule(3, function() {
            helpText = defaultHelpText; //reset message
        });
    }

    function drawSceneName() {
        var splitPath = (curScenePath + "").split("/");
        var fileName = splitPath[splitPath.length - 1];

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : new Vector(Luxe.screen.w / 2, 0),
            point_size : 16,
            text : fileName,
            immediate : true,
            batcher : uiSceneBatcher,
            align : TextAlign.center
        });
    }

    function drawPlayPauseText() {
        if (machine.current_state.name == "play") {
            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(Luxe.screen.w, 0),
                point_size : 16,
                text : "[P]ause",
                immediate : true,
                batcher : playModeUIBatcher,
                align : TextAlign.right
            });
        }
        else {
            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(Luxe.screen.w, 0),
                point_size : 16,
                text : "[P]lay",
                immediate : true,
                batcher : uiSceneBatcher,
                align : TextAlign.right
            });
        }
    }

    function drawModeText() {
        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : new Vector(Luxe.screen.w, 20),
            point_size : 16,
            text : "<[Q] " + curModeText + " [E]>",
            immediate : true,
            batcher : uiSceneBatcher,
            align : TextAlign.right
        });
        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : new Vector(Luxe.screen.w, 40),
            point_size : 16,
            text : "<[A] " + curToolText + " [D]>",
            immediate : true,
            batcher : uiSceneBatcher,
            align : TextAlign.right
        });
    }

    function drawTitle() {

        var anchorPoint = new Vector(Luxe.screen.w * 0.2, Luxe.screen.h * 0.2);

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : (new Vector(0,10)).add(anchorPoint),
            point_size : 20,
            text : "welcome to",
            immediate : true,
            batcher : uiSceneBatcher
        });

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : (new Vector(0,30)).add(anchorPoint),
            point_size : 60,
            text : "Snowglobe",
            immediate : true,
            batcher : uiSceneBatcher
        });

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : (new Vector(0,110)).add(anchorPoint),
            point_size : 20,
            text : "a videogame drafting tool",
            immediate : true,
            batcher : uiSceneBatcher
        });

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : (new Vector(0,140)).add(anchorPoint),
            point_size : 20,
            text : "by Adam Le Doux",
            immediate : true,
            batcher : uiSceneBatcher
        });

        Luxe.draw.text({
            color: new Color(1,1,1),
            pos : (new Vector(0,170)).add(anchorPoint),
            point_size : 16,
            text : "(draw anywhere to begin)",
            immediate : true,
            batcher : uiSceneBatcher
        });
    }

    function drawLayerNavigator() {
        Luxe.draw.box({
            x : 0,
            y : 0,
            w : 50,
            h : uiSceneCamera.size.y,
            batcher : uiSceneBatcher,
            immediate : true,
            color : new Color (0,0,0)
        });

        for (i in 0 ... layers.length) {
            var layerH = uiSceneCamera.size.y * ( 1 - ((i+1) / (layers.length+1)) );
            
            var isSelectedLayer = (i == curLayer);
            var isSelectedGroup = (layerNavMode == 2 && 
                            ( (layerGroupLastIndex > curLayer && i <= layerGroupLastIndex && i > curLayer) ||
                            (layerGroupLastIndex < curLayer && i >= layerGroupLastIndex && i < curLayer) )
                        );

            var unselectColor = new Color(1,1,1);
            var selectColor = new Color(1,1,0);
            if (layerNavMode == 1) selectColor = new Color(1,0,1);
            if (layerNavMode == 2) selectColor = new Color(0,1,0);

            var c = (isSelectedLayer || isSelectedGroup) ? selectColor : unselectColor;

            Luxe.draw.line({
                p0: new Vector(0, layerH),
                p1: new Vector(50, layerH),
                immediate: true,
                color: c,
                depth: 1000,
                batcher : uiSceneBatcher
            });
        }
    }

    //I gave up on this for now - come back later
    function drawGrid() {
        //trace(Luxe.camera.zoom);
        
        var baseGridSize = 50.0;
        var gridSize = baseGridSize;
        //var gridSize = baseGridSize * Luxe.camera.zoom;

        var x = (-totalCameraDragDist.x * Luxe.camera.zoom) % gridSize;
        var y = (-totalCameraDragDist.y * Luxe.camera.zoom) % gridSize;

        //trace(Luxe.camera.viewport.h);

        /*
        var zoomMult = Luxe.camera.zoom < 1.0 ? 1.0 / Luxe.camera.zoom : Luxe.camera.zoom;
        trace("ZZZZ " + zoomMult);
        */

        while (x < Luxe.screen.w) {
            Luxe.draw.line({
                p0 : new Vector(x, 0),
                p1 : new Vector(x, Luxe.screen.h),
                color : new Color(1,1,1,0.15),
                immediate : true,
                batcher : uiSceneBatcher
            });
            x += gridSize;
        }

        while (y < Luxe.screen.h) {    
            Luxe.draw.line({
                p0 : new Vector(0, y),
                p1 : new Vector(Luxe.screen.w, y),
                color : new Color(1,1,1,0.15),
                immediate : true,
                batcher : uiSceneBatcher
            }); 
            y += gridSize;
        }

    }

    override function onmousedown(e:MouseEvent) {
        //trace(e.button);
    }

    override function onmousemove(e:MouseEvent) {
    }

    override function onmouseup(e:MouseEvent) {
    }

    override function onwindowresized(e:WindowEvent) {

        uiSceneCamera.size = Luxe.screen.size; //this works!

        Luxe.camera.transform.pos.add(totalCameraDragDist);

        //trace(Luxe.camera.transform.pos);
    }

    /*
     * NEW UNDO / REDO
     */
    public function getEditorState() {
        //this hack fixes a dumb aliasing error
        //probably a better way to copy arrays exists though??
        var layerStackCopy = [];
        for (i in layerStack) {
            layerStackCopy.push(i);
        }

        var editorState = {
            sceneData : layers.jsonRepresentation(),
            componentData : componentManager.jsonRepresentation(),
            layerStack : layerStackCopy
        };

        return editorState;
    }

    public function saveEditorState() {
        doneStack.push(getEditorState());
        undoneStack = []; //clear undone stack when new action is recorded
    }

    public function undo() {
        if (doneStack.length > 1) {
            undoneStack.push( doneStack.pop() );
            recreateEditorState( doneStack[doneStack.length - 1] );
        }
    }

    public function redo() {
        if (undoneStack.length > 0) {
            recreateEditorState( undoneStack[undoneStack.length - 1] );
            doneStack.push( undoneStack.pop() );
        }
    }

    public function recreateEditorState(editorState : Dynamic) {
        wipeCurrentScene();
    
        //recreate layers from json
        //if (editorState.sceneData)
        for (p in (new Array<Polygon>()).createFromJson(editorState.sceneData)) {
            Edit.AddLayer(layers, p, curLayer+1);
            curLayer++;
        }

        //recreate components from json
        componentManager.updateFromJson(editorState.componentData);

        //traverse scene with layerStack to select the right polygon
        trace(editorState.layerStack);
        
        layerStack = editorState.layerStack;
        curLayer = layerStack[0];
        
        for (i in 1 ... layerStack.length) {
           var groupParent = curPoly();
           layers = groupParent.getChildrenAsPolys();
           curLayer = layerStack[i];
        }
        

        //this is bad code copy and pasting
        if (layers.length > 0) {    
            var poly : Polygon = layers[curLayer]; //cast(layers.getLayer(curLayer), Polygon);

            trace(layers);
            trace(poly);

            //close loop
            
            var loop = poly.getPoints();
            var start = loop[0];
            loop.push(start);

            trace(loop);
            

            
            selectedLayerOutline.setPoints(loop);

            polyCollision = poly.collisionBounds();
            
        }
        else {
            selectedLayerOutline.setPoints([]);
        }
        
    }

    public function wipeCurrentScene() {
        //delete all layers
        //delete all sub-layers
        for (l in layers) {
            l.destroy();
        }
        layers = [];
        //delete all components
        componentManager.componentData = [];
    }
    /*
     * NEW UNDO / REDO
     */

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

        /*
        curColorIcon = Luxe.draw.box({w: 30, h: 30, x: 0, y: 0, batcher: uiBatcher});
        curColorIcon.color = picker.pickedColor;
        */

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
        
        /*  
        Luxe.loadJSON("assets/ui/ed_ui_scene14.json", function(j) {

            (new Array<Polygon>()).createFromJson(j.json, uiSceneBatcher, uiScene);

            //TODO
            Luxe.loadJSON("assets/ui/ed_ui_scene14_components.json", function(j) {
                componentManager.updateFromJson(j.json);
                componentManager.activateComponents(uiScene);
            });

        });
        */
        

        playModeUIScene = new Scene("playModeUIScene");
        playModeUICamera = new Camera({name:"playModeUICamera", scene: playModeUIScene});
        playModeUIBatcher = Luxe.renderer.create_batcher({name: "playModeUIBatcher", layer: 11, camera: uiSceneCamera.view});
        //playModeUIBatcher = Luxe.renderer.create_batcher({name: "playModeUIBatcher", layer: 11, camera: playModeUICamera.view});

        /*
        Luxe.loadJSON("assets/ui/play_ui_scene2.json", function(j) {

            (new Array<Polygon>()).createFromJson(j.json, playModeUIBatcher, playModeUIScene);

            //TODO
            Luxe.loadJSON("assets/ui/play_ui_scene2_components.json", function(j) {
                componentManager.updateFromJson(j.json);

                Luxe.renderer.remove_batch(playModeUIBatcher); //make it invisible
            });

        });
        */
        
        
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

    /*
     * NEW GROUPED LAYERS CODE
     */ 

    function editGroup(parent : Polygon) {
        layers = parent.getChildrenAsPolys();
        localSpace = parent.transform;
        
        curLayer = 0;
        layerStack.push(curLayer);
        trace(layerStack);
        switchLayerSelection(0); //hack
    }

    function exitCurrentGroup() {
        if (layers[0].parent.parent != null) {
            var newParent = cast(layers[0].parent.parent, Polygon);
            layers = newParent.getChildrenAsPolys();
            localSpace = newParent.transform;
        }
        else {
            layers = rootLayers;
            localSpace = new Transform(); 
            //this is kind of a crappy hack - should I have a global root polygon??
            //or do I need to restructure groups so they don't use empty polygons as containers???
        }

        layerStack.pop();
        curLayer = layerStack[layerStack.length - 1];
        trace(layerStack);
        switchLayerSelection(0); //hack
    }

    //BUGGY AS FUCK
    //NOTE: THIS MIGHT NOT WORK FOR DEEP LAYERS
    function ungroupLayers(parent : Polygon) {
        //keep track of layer indices
        var i = curLayer;
        var tmpParentPos = parent.pos.clone();
        var tmpParentScale = parent.scale.clone();
        var tmpParentRotZ = parent.rotation_z;

        //remove parent
        Edit.RemoveLayer(layers, i);

        //remove children from parent and keep a list of the polygons
        var polyList : Array<Polygon> = [];
        for (c in parent.children) {
            var p = cast(c, Polygon);
            polyList.push(p);
        }

        //add polygons to parent's layer and re-adjust their transforms to new coord system
        for (p in polyList) {
            var worldPos = p.pos.toWorldSpace(parent.transform);

            p.parent = parent.parent;
            Edit.AddLayer(layers, p, i); //I expect this to break at lower levels

            p.pos = worldPos;
            p.scale.multiply(tmpParentScale);
            p.rotation_z += tmpParentRotZ;

            i++;
        }

        switchLayerSelection(i-1);
    }

    /*
     * NEW GROUPED LAYERS CODE
     */ 

    //COMBINE THESE TWO FUNCTION OBVIOUSLY \/\/\/\/
    public function switchLayerSelection(dir:Int) {
        curLayer += dir;

        if (curLayer < 0) curLayer = 0;
        if (curLayer >= layers.length) curLayer = layers.length - 1;

        if (layers.length > 0) {    
            var poly : Polygon = layers[curLayer]; //cast(layers.getLayer(curLayer), Polygon);

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

        layerStack[layerStack.length-1] = curLayer;
        trace("layer stack update " + layerStack);
    }

    public function goToLayer(index:Int) {
        if (layers.length > 0) {
            curLayer = index;

            var poly : Polygon = layers[curLayer];

            //close loop
            var loop = poly.getPoints();
            var start = loop[0];
            loop.push(start);

            selectedLayerOutline.setPoints(loop);

            polyCollision = poly.collisionBounds();

            layerStack[layerStack.length-1] = curLayer;
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
            saveEditorState(); //record state for undo / redo

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

    //TODO: fix the mouse being "stuck" to the center of the polygon
    public function layerDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        //var poly = cast(layers.getLayer(curLayer), Polygon);
        var poly = layers[curLayer];

        /*
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);
        trace(drag);
        if (localSpace != null) drag = localSpace.worldVectorToLocalSpace(drag);
        trace(drag);
        
        //poly.transform.pos.add(drag);
        poly.pos.add(drag);
        */

        if (localSpace != null) mousePos = localSpace.worldVectorToLocalSpace(mousePos);
        poly.pos = mousePos;

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
        //trace(Luxe.camera.transform.pos);

        totalCameraDragDist.add(drag);

        dragMouseStartPos = screenPos;
    }

    public function undoRedoInput(e:KeyEvent) {
        //OLD
        /*
       if (e.keycode == Key.key_z) {
            //Undo
            Edit.Undo();
        }
        else if (e.keycode == Key.key_x) {
            //Redo
            Edit.Redo();
        } 
        */

       if (e.keycode == Key.key_z) {
            //Undo
            undo();
        }
        else if (e.keycode == Key.key_x) {
            //Redo
            redo();
        } 
    }

    //OLD UNDO / REDO
    /*
    public function Undo() {
        Edit.Undo();
    }

    public function Redo() {
        Edit.Redo();
    }
    */

    public function selectLayerInput(e:KeyEvent) {
        //OLD
        /*
        if (e.keycode == Key.key_a) {
            //Go up a layer
            switchLayerSelection(-1);
        }
        else if (e.keycode == Key.key_s) {
            //Go down a layer
            switchLayerSelection(1);
        }
        */

        if (e.keycode == Key.key_s && e.mod.none) {
            //Go up a layer
            switchLayerSelection(-1);

            activateLayerNavigator(0);
        }
        else if (e.keycode == Key.key_w && e.mod.none) {
            //Go down a layer
            switchLayerSelection(1);

            activateLayerNavigator(0);
        }
    }

    public function activateLayerNavigator(mode : Int) {
        if (layerNavMode == 0) setHelpMessage("Select layer");
        if (layerNavMode == 1) setHelpMessage("Move layer");
        if (layerNavMode == 2) setHelpMessage("Group layers");

        isLayerNavigatorActive = true;
        navUpTimer.reset();
        navUpTimer.schedule(layerNavUpTime, function() {isLayerNavigatorActive = false;});
        layerNavMode = mode;
    }

    public function deleteLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_p) {  
            //Delete selected layer

            /*
            if (layers.getNumLayers() > 0) {    
                Edit.RemoveLayer(layers, curLayer);
                switchLayerSelection(-1);
            }
            */


            if (layers.length > 0) {    
                Edit.RemoveLayer(layers, curLayer);
                switchLayerSelection(-1);

                saveEditorState();
            }
        }
    }

    public function duplicateLayerInput(e:KeyEvent) {
        /*
        if (e.keycode == Key.key_d) {
            if (layers.getNumLayers() > 0) {    
                var layerDupe = new Polygon({}, [], cast(layers.getLayer(curLayer), Polygon).jsonRepresentation());
                layerDupe.transform.pos.add(new Vector(10,10));
                Edit.AddLayer(layers, layerDupe, curLayer);
                switchLayerSelection(1);
            }
        }
        */
        if (e.keycode == Key.key_d) {
            if (layers.length > 0) {    
                var layerDupe = new Polygon({}, [], layers[curLayer].jsonRepresentation());
                layerDupe.transform.pos.add(new Vector(10,10));
                Edit.AddLayer(layers, layerDupe, curLayer);
                switchLayerSelection(1);
            }
        }
    }

    public function moveLayerInput(e:KeyEvent) {
        //NEW
        if (e.keycode == Key.key_s && e.mod.shift) {
            //Move selected layer down the stack
            if (curLayer > 0) {
                //Edit.MoveLayer(layers, curLayer, -1);
                layers.swap(curLayer, curLayer - 1);
                switchLayerSelection(-1);
                activateLayerNavigator(1);
            }
        }
        else if (e.keycode == Key.key_w && e.mod.shift) {
            //Move selected layer up the stack
            if (curLayer < layers.length - 1) {
                //Edit.MoveLayer(layers, curLayer, 1);    
                layers.swap(curLayer, curLayer + 1);
                switchLayerSelection(1);
                activateLayerNavigator(1);
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
            var tmp = layers[curLayer].color.clone().toColorHSV(); //layers.getLayer(curLayer).color.clone().toColorHSV();
            picker.pickedColor = tmp;
            slider.value = tmp.v;

            addColorToList(picker.pickedColor);
        }
        else if (e.keycode == Key.key_n) {
            //drop color
            //layers.getLayer(curLayer).color = picker.pickedColor.clone();
            //Edit.ChangeColor(layers.getLayer(curLayer), picker.pickedColor.clone());
            Edit.ChangeColor(layers[curLayer], picker.pickedColor.clone());

            saveEditorState();
        }
    }

    public function addCircleInput(e:KeyEvent) {
        if (e.keycode == Key.key_t) {
            var worldMousePos = Luxe.camera.screen_point_to_world(Luxe.screen.cursor.pos);
            var points : Array<Vector> = [];
            points = points.makeCirclePolyline(worldMousePos, (Luxe.screen.w / 50) / Luxe.camera.zoom);

            trace(points);

            //var newPLine = new Polyline({color: picker.color}, points);
            var newPolygon = new Polygon({color: picker.pickedColor.clone()}, points);
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

    //no dialog version of save (MERGE these)
    public function SaveAuto(path : String) {
        //are these two lines of code dumb?
        var splitPath = (path + "").split("/");
        var fileName = splitPath[splitPath.length - 1];

        //THIS BREAKS :(
        //if (sys.FileSystem.exists(path)) sys.FileSystem.deleteDirectory(path);

        sys.FileSystem.createDirectory(path);
        sys.FileSystem.createDirectory(path + "/components");

        //scene file
        var output = File.write(path + "/" + fileName + ".scene", false);

        var outObj = layers.jsonRepresentation();
        var outStr = haxe.Json.stringify(outObj);
        output.writeString(outStr);

        output.close();

        //component files
        var componentData = componentManager.jsonRepresentation();
        for (c in componentData) {
            var output = File.write(path + "/components/" + c.name + ".json", false);

            var outStr = haxe.Json.stringify(c, null, "    ");
            output.writeString(outStr);

            output.close();
        }

        if (curScenePath != null) Luxe.core.app.io.platform.watch_remove(curScenePath);
        curScenePath = path;
        Luxe.core.app.io.platform.watch_add(curScenePath);
    }

    public function Save() {
        //save
        var rawPath = Luxe.core.app.io.platform.dialog_save().split(".");
        var path = rawPath[0];
        var splitPath = (path + "").split("/");
        var fileName = splitPath[splitPath.length - 1];

        //THIS BREAKS :(
        //if (sys.FileSystem.exists(path)) sys.FileSystem.deleteDirectory(path);
        
        sys.FileSystem.createDirectory(path);
        sys.FileSystem.createDirectory(path + "/components");

        //scene file
        var output = File.write(path + "/" + fileName + ".scene", false);

        var outObj = layers.jsonRepresentation();
        var outStr = haxe.Json.stringify(outObj);
        output.writeString(outStr);

        output.close();

        //component files
        var componentData = componentManager.jsonRepresentation();
        for (c in componentData) {
            var output = File.write(path + "/components/" + c.name + ".json", false);

            var outStr = haxe.Json.stringify(c, null, "    ");
            output.writeString(outStr);

            output.close();
        }

        if (curScenePath != null) Luxe.core.app.io.platform.watch_remove(curScenePath);
        curScenePath = path;
        Luxe.core.app.io.platform.watch_add(curScenePath);

        //OLD VERSION
        /*
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
        */

    }

    public function Load() {
        //load

        //TODO replace with "dialog_folder"
        var rawOpenFileName = Luxe.core.app.io.platform.dialog_open().split(".");
        var openFileName = rawOpenFileName[0];

        trace("file " + openFileName);

        if (rawOpenFileName[1] == "scene") { //NEW VERSION
            trace('new load! ' + openFileName);
            var splitPath = (openFileName + "").split("/");
            var fileName = splitPath[splitPath.length - 1];

            //reconstruct parent path
            var path = "";
            for (i in 0 ... splitPath.length - 1) {
                path += splitPath[i] + "/";
            }

            //
            //scene file
            var input = File.read(path + fileName + ".scene", false);

            var polys = input.readScene(Luxe.renderer.batcher, Luxe.scene);

            //TODO - rewrite the layer manager
            for (p in polys) {
                Edit.AddLayer(layers, p, curLayer+1);
                switchLayerSelection(1);
            }

            input.close();

            //component files
            
            var componentFiles = sys.FileSystem.readDirectory(path + "components");

            for (compFile in componentFiles) {

                //trace(path + "components/" + compFile);

                var input = File.read(path + "components/" + compFile, false);

                //read all - regardless of how many lines it is
                var inStr = "";
                while (!input.eof()) {
                    inStr += input.readLine();
                }

                var inObj = haxe.Json.parse(inStr);

                componentManager.addComponentFromJson(inObj);

                input.close();
            }

            //save path to current scene (and chop off that extra forward slash HACK)
            if (curScenePath != null) Luxe.core.app.io.platform.watch_remove(curScenePath);
            curScenePath = path.substring(0,path.length-1);
            Luxe.core.app.io.platform.watch_add(curScenePath);
            trace("LOAD " + curScenePath);
        }
        else { //OLD VERSION
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

            componentManager.updateFromJson(inObj, true);

            componentManager.jsonRepresentation();

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
        //if (e.pos.x < Luxe.screen.w * 0.85) { //HORRIBLE HACKS

            var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
            curLine = new Polyline({color: picker.pickedColor.clone(), depth: aboveLayersDepth+1}, [mousepos]);
            isDrawing = true;
        //}
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
        var pos = p.transform.pos;
        if (localSpace != null) pos = localSpace.localVectorToWorldSpace(pos);
        var b = p.getRectBounds();
        var handlePos = Vector.Subtract( pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        Luxe.draw.line({
            p0 : pos,
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

        //TURN THIS INTO A FUNCTION or something
        var p = curPoly();
        var pos = p.transform.pos;
        if (localSpace != null) pos = localSpace.localVectorToWorldSpace(pos);
        var b = p.getRectBounds();
        var handlePos = Vector.Subtract( pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        if (mousePos.distance(handlePos) < (15 / Luxe.camera.zoom)) {
            return true;
        }

        return false;
    }

    public function rotationDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var p = curPoly();
        var pos = p.transform.pos;
        if (localSpace != null) pos = localSpace.localVectorToWorldSpace(pos);

        var rotationDir = Vector.Subtract(mousePos, pos);
        p.rotation_z = Maths.degrees(rotationDir.angle2D) - 90 - (p.transform.scale.y > 0 ? 180 : 0); // - 270;
        if (localSpace != null) p.rotation_z -= localSpace.getRotationZ();

        switchLayerSelection(0);
    }

    function scaleHandles() {
        var p = curPoly();
        var pos = p.transform.pos;
        if (localSpace != null) pos = localSpace.localVectorToWorldSpace(pos);

        var b = p.getRectBounds();

        var upPos = Vector.Add( pos, p.transform.up().multiplyScalar(b.h * 0.7 /* * 0.5 */ /* * 0.7 */) );
        var rightPos = Vector.Add( pos, p.transform.right().multiplyScalar(b.w * 0.7 /* * 0.5 */ /* * 0.7 */) );

        var handleSize = 10 / Luxe.camera.zoom;

        return {size: handleSize, up: upPos, right: rightPos, origin: pos};
    }

    public function drawScaleHandles() {
        //if (curPoly().points.length == 0) return false; //currently turning off scaling for groups
        //since I can't figure out how to make it work right

        var handles = scaleHandles();

        //third handle
        Luxe.draw.rectangle({
            x : handles.origin.x - (handles.size * 2 / 2),
            y : handles.origin.y - (handles.size * 2 / 2),
            h : handles.size * 2,
            w : handles.size * 2,
            color : new Color(150,255,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        if (curPoly().points.length == 0) return false; //only draw third handle for groups

        Luxe.draw.line({
            p0 : handles.origin,
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
            p0 : handles.origin,
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

        return true;
    }

    function collisionWithScaleHandle(mousePos) : Bool {
        //if (curPoly().points.length == 0) return false; //currently turning off scaling for groups
        //since I can't figure out how to make it work right

        var handles = scaleHandles();

        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var mouseCollider = new CollisionCircle(mousePos.x, mousePos.y, 5);
        var handleColliderUp = new CollisionCircle(handles.up.x, handles.up.y, handles.size * 0.7); //this collision circle is kind of a hack, but it should be "close enough"
        var handleColliderRight = new CollisionCircle(handles.right.x, handles.right.y, handles.size * 0.7);
        var handleColliderCenter = new CollisionCircle(handles.origin.x, handles.origin.y, handles.size * 1.2);
        if (Collision.test(mouseCollider, handleColliderUp) != null) {
            scaleDirLocal = new Vector(0,1); // NOT A GREAT WAY TO DO THIS
            //scaleDirWorld = curPoly().transform.up();
            if (curPoly().points.length == 0) return false; //hack
            return true;
        }
        else if (Collision.test(mouseCollider, handleColliderRight) != null) {
            scaleDirLocal = new Vector(1,0);
            //scaleDirWorld = curPoly().transform.right();
            if (curPoly().points.length == 0) return false; //hack
            return true;
        }
        else if (Collision.test(mouseCollider, handleColliderCenter) != null) {
            scaleDirLocal = new Vector(1,1);
            return true;
        }
        else {
            return false;
        }
    }

    public function startScaleDrag(mousePos) : Bool {
        if (collisionWithScaleHandle(mousePos)) {
            dragMouseStartPos = Luxe.camera.screen_point_to_world(mousePos);
            if (scaleDirLocal.x == 1 && scaleDirLocal.y == 1) {
                scaleDirWorld = dragMouseStartPos.clone().subtract( scaleHandles().origin ).normalized;
            }
            return true;
        }
        return false;
    }

    //this mostly works (but could be better)
    public function scaleDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        if (scaleDirLocal.x == 1 && scaleDirLocal.y == 1) {
            //do nothing for now
        }
        else if (scaleDirLocal.x != 0) {
            scaleDirWorld = curPoly().transform.right();
        }
        else {
            scaleDirWorld = curPoly().transform.up();
        }

        var scaleDelta = Vector.Multiply(scaleDirLocal, drag.dot(scaleDirWorld));
        scaleDelta.x = (scaleDelta.x / curPoly().getRectBounds().w) * curPoly().transform.scale.x * 2;
        scaleDelta.y = (scaleDelta.y / curPoly().getRectBounds().h) * curPoly().transform.scale.y * 2;

        /*
        if (curPoly().points.length == 0) { //is group 
            //solution for scaling groups is currently kind of a fake
            //is that OKAY???
            curPoly().scaleChildren(scaleDelta);
        }
        else {
            curPoly().transform.scale.add(scaleDelta);
        }
        */
        curPoly().scale = Vector.Add(curPoly().scale, scaleDelta);// add();

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
        if (!areVerticesTooCloseToHandle()) {  //NOTE: //this is where grouped-polygons get disqualified
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

        //if (localSpace != null) mousePos = localSpace.worldVectorToLocalSpace(mousePos);
        mousePos = curPoly().transform.worldVectorToLocalSpace(mousePos);

        /*
        var points = curPoly().getPoints();
        points[selectedVertex] = mousePos.clone();
        switchLayerSelection(0);
        */

        layers[curLayer].points[selectedVertex] = mousePos.clone();
        layers[curLayer].recenterLocally();
        layers[curLayer].generateMesh();
        switchLayerSelection(0);

        //curPoly().setPoints(points);

        /*
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        var points = curPoly().getPoints();
        points[selectedVertex].add(drag);
        switchLayerSelection(0);

        curPoly().setPoints(points);

        dragMouseStartPos = mousePos;
        */
    }

    function areVerticesTooCloseToHandle() {
        if (curPoly().points.length == 0) return true; //don't manipulate child's vertices
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
        return layers[curLayer]; //cast(layers.getLayer(curLayer), Polygon);
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
        if (main.layers.length > 0) {

            main.drawScaleHandles();
            main.drawRotationHandle();
            main.drawVertexHandles();
        }
    }

    override function onmousedown(e:MouseEvent) {
        if (main.layers.length > 0) {


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
    }

    override function onmousemove(e:MouseEvent) {
        if (main.layers.length > 0) {

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
    }

    override function onmouseup(e:MouseEvent) {
        if (main.layers.length > 0) {

            //undo / redo for: scaling, rotating, vertex editing, translating
            if (draggingScale || draggingRotation || draggingVertex || draggingLayer) {
                main.saveEditorState();
            } 

            draggingVertex = false;
            draggingLayer = false;
            draggingRotation = false;
            draggingScale = false;
        }
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
            for (v in main.layers) { //main.layers.layers) {
                //var poly = cast(v, Polygon);
                var poly = v;
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
                    //main.layers.removeLayer(childPoly);
                    main.layers.remove(childPoly);
                    childPoly.parent = parentPoly;
                }

                parentPoly.recenter();

                //main.layers.addLayer(parentPoly);
                main.layers.push(parentPoly);

                main.layers.setDepths(0,1);
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