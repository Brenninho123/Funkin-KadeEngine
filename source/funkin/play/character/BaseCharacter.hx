package funkin.play.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import haxe.Json;

using StringTools;

typedef CharacterAnimData =
{
	var name:String;
	var anim:String;
	var fps:Int;
	var ?loop:Bool;
	var ?indices:Array<Int>;
	var ?offsets:Array<Float>;
}

typedef CharacterData =
{
	var image:String;
	var ?library:String;
	var ?atlasType:String;
	var ?scale:Float;
	var ?flipX:Bool;
	var ?antialiasing:Bool;
	var ?healthIcon:String;
	var ?position:Array<Float>;
	var ?danceIdle:Bool;
	var ?flipAnimsOnPlayer:Bool;
	var ?vocalsFile:String;
	var animations:Array<CharacterAnimData>;
}

class BaseCharacter extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';
	public var stunned:Bool = false;

	public var holdTimer:Float = 0;

	public var healthIcon:String = 'face';

	var data:CharacterData;
	var danced:Bool = false;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		curCharacter = character;
		this.isPlayer = isPlayer;

		antialiasing = true;

		loadCharacter(character);
	}

	function loadCharacter(character:String):Void
	{
		var rawJson:String = Paths.json('characters/$character');
		data = cast Json.parse(rawJson);

		if (data.atlasType == "packer")
			frames = Paths.getPackerAtlas(data.image, data.library);
		else
			frames = Paths.getSparrowAtlas(data.image, data.library);

		for (animData in data.animations)
		{
			if (animData.indices != null && animData.indices.length > 0)
				animation.addByIndices(animData.name, animData.anim, animData.indices, "", animData.fps, animData.loop == true);
			else
				animation.addByPrefix(animData.name, animData.anim, animData.fps, animData.loop == true);

			var offX:Float = 0;
			var offY:Float = 0;
			if (animData.offsets != null)
			{
				if (animData.offsets.length > 0)
					offX = animData.offsets[0];
				if (animData.offsets.length > 1)
					offY = animData.offsets[1];
			}
			addOffset(animData.name, offX, offY);
		}

		if (data.scale != null && data.scale != 1)
		{
			setGraphicSize(Std.int(width * data.scale));
			updateHitbox();
		}

		if (data.antialiasing != null)
			antialiasing = data.antialiasing;

		if (data.healthIcon != null)
			healthIcon = data.healthIcon;

		if (hasAnim('idle'))
			playAnim('idle');
		else if (hasAnim('danceRight'))
			playAnim('danceRight');

		if (isPlayer)
		{
			flipX = !flipX;

			if (data.flipAnimsOnPlayer == true)
			{
				swapAnimFrames('singLEFT', 'singRIGHT');
				swapAnimFrames('singLEFTmiss', 'singRIGHTmiss');
			}
		}
		else if (data.flipX == true)
		{
			flipX = !flipX;
		}
	}

	function swapAnimFrames(nameA:String, nameB:String):Void
	{
		var animA = animation.getByName(nameA);
		var animB = animation.getByName(nameB);

		if (animA == null || animB == null)
			return;

		var oldFrames = animA.frames;
		animA.frames = animB.frames;
		animB.frames = oldFrames;
	}

	inline public function hasAnim(name:String):Bool
	{
		return animation.getByName(name) != null;
	}

	override function update(elapsed:Float)
	{
		if (animation.curAnim != null)
		{
			if (animation.curAnim.name.startsWith('sing'))
				holdTimer += elapsed;
			else
				holdTimer = 0;

			if (!debugMode)
			{
				if (isPlayer && animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
				{
					playAnim('idle', true, false, 10);
				}

				if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
				{
					playAnim('deathLoop');
				}

				if (!isPlayer && data.danceIdle == true)
				{
					var danceVar:Float = 4;

					if (curCharacter == 'dad')
						danceVar = 6.1;

					if (holdTimer >= Conductor.stepCrochet * danceVar * 0.001)
					{
						dance();
						holdTimer = 0;
					}
				}

				if (curCharacter == 'gf' && animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
					playAnim('danceRight');
			}
		}

		super.update(elapsed);
	}

	public function dance():Void
	{
		if (debugMode)
			return;

		if (data.danceIdle == true)
		{
			if (hasAnim('hairBlow') && animation.curAnim.name.startsWith('hair'))
				return;

			danced = !danced;

			if (danced && hasAnim('danceRight'))
				playAnim('danceRight');
			else if (hasAnim('danceLeft'))
				playAnim('danceLeft');
		}
		else if (hasAnim('idle'))
		{
			playAnim('idle');
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;
			else if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}
}
