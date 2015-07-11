package states;

import luxe.States;
import luxe.Vector;
import luxe.collision.ShapeDrawerLuxe;
import luxe.Input;
import luxe.Entity;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.collision.Collision;
import luxe.Color;
import luxe.utils.Maths;

import animation.Bone;
import components.Rigging;
import components.PuppetAnimation;

using utilities.VectorExtender;
using utilities.TransformExtender;

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

    var toolMode = 0; //0 == skeleton, 1 == rig, 2 == animate

    //debug
    var drawer : ShapeDrawerLuxe = new ShapeDrawerLuxe();

    //
    var curFrame : Int = 0;

    //multiselect bones
    var multiselectBones : Array<Bone> = [];

    function updateBoneArray() {
        boneArray = main.getAllBonesInScene();
        /*
        boneArray = [];

        var rootBones : Array<Entity> = [];
        Luxe.scene.get_named_like("Bone.*", rootBones); //find root bones

        for (b in rootBones) {
            var root = cast b;
            boneArray = boneArray.concat(root.skeleton());
        }
        */
    }

    override function init() {
    } //init

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
        trace("hi");
        Luxe.renderer.add_batch(main.boneBatcher);

        //stupid copy paste
        if (toolMode == 0) main.curToolText = "skeleton";
        if (toolMode == 1) main.curToolText = "rigging";
        if (toolMode == 2) main.curToolText = "animation";

        //haaaaaaack
        main.componentManager.activateComponents(Luxe.scene, "Rigging");

    } //onenter

    override function onleave<T>( _main:T ) {
        main.curToolText = "tool select";
        trace("bi!");
        Luxe.renderer.remove_batch(main.boneBatcher);
        trace(Luxe.renderer.batchers);
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

            if (e.button == MouseButton.left && toolMode == 0) { //make bone
                isMakingBone = true;
                startPos = Luxe.camera.screen_point_to_world(e.pos);
                endPos = startPos.clone(); 
            }
            else if (e.button == MouseButton.right) { //select bone
                selectBone(null);
                for (b in boneArray) {
                    //var bone = cast(b, Bone); //cast to bone
                    if (Collision.test(mouseCollisionShape, b.collisionShape()) != null) {
                        selectBone(b);
                    }
                }
            }

            if (e.button == MouseButton.left && toolMode == 1) { //multiselect bones
                for (b in boneArray) {
                    if (Collision.test(mouseCollisionShape, b.collisionShape()) != null) {
                        if (multiselectBones.lastIndexOf(b) != -1) {
                            multiselectBones.remove(b);

                            if (selectBone != null && b == selectedBone) {
                                b.color = new Color(1, 1, 0);
                            }
                            else {
                                b.color = new Color(1, 1, 1);
                            }
                        }
                        else {
                            if (Luxe.input.keydown(Key.lalt)) {
                                multiselectBones = multiselectBones.concat(b.skeleton());
                                for (mb in multiselectBones) {
                                    mb.color = new Color(0.7, 0, 1);
                                }
                            }
                            else {
                                multiselectBones.push(b);
                                b.color = new Color(0.7, 0, 1);
                            }
                        }
                    }
                }
            }

            //old version
            /*
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
            */

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

        //old
        if (toolMode == 2) { //animation
            Luxe.draw.text({
                color: new Color(255,255,255),
                pos : new Vector(Luxe.screen.mid.x, 30),
                point_size : 20,
                text : "Frame: " + curFrame,
                immediate : true,
                batcher : main.uiBatcher
            });
        }

        if (toolMode == 1) { //rigging
            if (main.curPoly() != null && main.curPoly().has("Rigging")) {
                cast(main.curPoly().get("Rigging"), Rigging).drawRigging();
            }
        }

    }

    override function onkeydown(e:KeyEvent) {

        if (e.keycode == Key.key_a) {
            toolMode = (toolMode - 1);
            if (toolMode < 0) toolMode = 2; //hack (mod isn't working???)

            if (toolMode == 1) {
                multiselectBones = [];
            }
            else {
                for (b in multiselectBones) {
                    if (selectedBone != null && b == selectedBone) {
                        b.color = new Color(1,1,0);
                    }
                    else {
                        b.color = new Color(1,1,1);
                    }
                }
            }
        }
        else if (e.keycode == Key.key_d) {
            toolMode = (toolMode + 1) % 3;

            if (toolMode == 1) {
                multiselectBones = [];
            }
            else {
                for (b in multiselectBones) {
                    if (selectedBone != null && b == selectedBone) {
                        b.color = new Color(1,1,0);
                    }
                    else {
                        b.color = new Color(1,1,1);
                    }
                }
            }
        }

        if (toolMode == 0) main.curToolText = "skeleton";
        if (toolMode == 1) main.curToolText = "rigging";
        if (toolMode == 2) main.curToolText = "animation";

        main.selectLayerInput(e);
        main.zoomInput(e);

        //old animation
        if (boneArray.length > 0 && toolMode == 2) {
            var skeletonRoot = boneArray[0];

            if (e.keycode == Key.leftbracket) {
                curFrame++;
                skeletonRoot.frameIndex = curFrame;
            }
            else  if (e.keycode == Key.rightbracket) {
                curFrame--;
                skeletonRoot.frameIndex = curFrame;
            }

            curFrame = skeletonRoot.frameIndex; //make sure we don't get a mismatch or go out of bounds

            /*
            if (e.keycode == Key.key_a) {
                skeletonRoot.animate(1);
            }
            */
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
        
        //old show / hide bones
        /*
        if (e.keycode == Key.key_i) {
            Luxe.renderer.remove_batch(main.boneBatcher);
        }
        else if (e.keycode == Key.key_u) {
            Luxe.renderer.add_batch(main.boneBatcher);
        }
        */
        

        //old rigging
        /*
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
        */

        if (e.keycode == Key.key_b) {
            //leave animation mode
            machine.set("draw", main);
        }

        //new rigging
        if (toolMode == 1) {
            if (e.keycode == Key.key_r && e.mod.ctrl && multiselectBones.length > 0) { //rig poly w/ selected bones
               
                for (p in main.getSelectedGroup()) {
                    trace(p);

                    //if (p.has("Animation")) p.remove("Animation");
                    if (!p.has("Rigging")) {
                        p.add(new Rigging({name: "Rigging"}));
                        main.componentManager.addComponent(cast(p, Entity), "Rigging");
                    }
                    
                    //cast(p.get("Animation"), Animation).setBones(multiselectBones);
                    
                    cast(p.get("Rigging"), Rigging).addBones(multiselectBones);
                }

                /*
                main.curPoly().add(new Animation({name: "Animation"}));
                cast(main.curPoly().get("Animation"), Animation).setBones(multiselectBones);
                */
            }

            if (e.keycode == Key.key_r && e.mod.alt && multiselectBones.length > 0) { //rig poly w/ selected bones
               
                for (p in main.getSelectedGroup()) {
                    
                    //cast(p.get("Animation"), Animation).setBones(multiselectBones);
                    if (p.has("Rigging")) {
                        cast(p.get("Rigging"), Rigging).removeBones(multiselectBones);
                    }
                    
                }

                /*
                main.curPoly().add(new Animation({name: "Animation"}));
                cast(main.curPoly().get("Animation"), Animation).setBones(multiselectBones);
                */
            }
        }
    } 

    function selectBone(b : Bone) {
        if (selectedBone != null) {
            selectedBone.color = new Color(255,255,255);
        }
        selectedBone = b;
        if (selectedBone != null) {
            selectedBone.color = new Color(255,255,0);
        }
    }
}