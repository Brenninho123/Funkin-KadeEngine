package funkin.play.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
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
	var ?iconOffsets:Array<Float>;
	var ?position:Array<Float>;
	var ?cameraOffsets:Array<Float>;
	var ?danceIdle:Bool;
	var ?danceSteps:Array<String>;
	var ?singSuffix:String;
	var ?singDuration:Float;
	var ?flipAnimsOnPlayer:Bool;
	var ?vocalsFile:String;
	var ?vocalsVolume:Float;
	var ?heyEnabled:Bool;
	var ?heyDuration:Float;
	var animations:Array<CharacterAnimData>;
}

class BaseCharacter extends FlxSprite
{
	static var dataCache:Map<String, CharacterData> = new Map<String, CharacterData>();

	public static inline var DEFAULT_CHARACTER:String = "bf";

	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var stunned:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var healthIcon:String = 'face';
	public var iconOffsets:Array<Float> = [0, 0];
	public var cameraOffsets:Array<Float> = [0, 0];
	public var vocalsFile:String;
	public var vocalsVolume:Float = 1;

	public var onAnimationFinish:String->Void;

	var data:CharacterData;
	var danceIndex:Int = 0;
	var singSuffix:String = "";
	var singTimer:Float = 0;
	var heyTimer:Float = 0;
	var isHeying:Bool = false;
	var lockedAnim:String = null;

	public function new(x:Float, y:Float, ?character:String = DEFAULT_CHARACTER, ?isPlayer:Bool = false)
	{
		super(x, y);

		curCharacter = character;
		this.isPlayer = isPlayer;

		antialiasing = true;

		loadCharacter(character);

		animation.finishCallback = onFlxAnimFinish;
	}

	function loadCharacter(character:String):Void
	{
		data = getCharacterData(character);

		if (data == null)
		{
			FlxG.log.error('Character data missing for "$character", falling back to "$DEFAULT_CHARACTER"');
			curCharacter = DEFAULT_CHARACTER;
			data = getCharacterData(DEFAULT_CHARACTER);
		}

		if (data == null)
		{
			FlxG.log.error('Fallback character "$DEFAULT_CHARACTER" also missing, aborting load');
			return;
		}

		buildGraphic();
		buildAnimations();
		applyScaleAndFlags();
		applyStartingAnim();
		applyPlayerFlip();
	}

	static function getCharacterData(character:String):CharacterData
	{
		if (dataCache.exists(character))
			return dataCache.get(character);

		var path = Paths.getPreloadPath('characters/$character.json');
		if (!openfl.utils.Assets.exists(path) && !sys.FileSystem.exists(path))
			return null;

		var parsed:CharacterData = null;
		try
		{
			var raw:String = openfl.utils.Assets.getText(path);
			parsed = cast Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Failed to parse character json for "$character": $e');
			return null;
		}

		dataCache.set(character, parsed);
		return parsed;
	}

	public static function clearCache():Void
	{
		dataCache.clear();
	}

	public static function preload(characters:Array<String>):Void
	{
		for (c in characters)
			getCharacterData(c);
	}

	function buildGraphic():Void
	{
		if (data.atlasType == "packer")
			frames = Paths.getPackerAtlas(data.image, data.library);
		else
			frames = Paths.getSparrowAtlas(data.image, data.library);
	}

	function buildAnimations():Void
	{
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
	}

	function applyScaleAndFlags():Void
	{
		if (data.scale != null && data.scale != 1)
		{
			setGraphicSize(Std.int(width * data.scale));
			updateHitbox();
		}

		if (data.antialiasing != null)
			antialiasing = data.antialiasing;

		if (data.healthIcon != null)
			healthIcon = data.healthIcon;

		if (data.iconOffsets != null && data.iconOffsets.length >= 2)
			iconOffsets = [data.iconOffsets[0], data.iconOffsets[1]];

		if (data.cameraOffsets != null && data.cameraOffsets.length >= 2)
			cameraOffsets = [data.cameraOffsets[0], data.cameraOffsets[1]];

		if (data.position != null && data.position.length >= 2)
		{
			x += data.position[0];
			y += data.position[1];
		}

		if (data.vocalsFile != null)
			vocalsFile = data.vocalsFile;

		if (data.vocalsVolume != null)
			vocalsVolume = data.vocalsVolume;

		singSuffix = data.singSuffix != null ? data.singSuffix : "";
	}

	function applyStartingAnim():Void
	{
		if (data.danceIdle == true && data.danceSteps != null && data.danceSteps.length > 0)
			playAnim(data.danceSteps[0]);
		else if (hasAnim('idle'))
			playAnim('idle');
		else if (hasAnim('danceRight'))
			playAnim('danceRight');
	}

	function applyPlayerFlip():Void
	{
		if (isPlayer)
		{
			flipX = !flipX;

			if (data.flipAnimsOnPlayer == true)
			{
				swapAnimFrames('singLEFT' + singSuffix, 'singRIGHT' + singSuffix);
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

	public function getCameraPosition():FlxPoint
	{
		return FlxPoint.get(getMidpoint().x + cameraOffsets[0], getMidpoint().y + cameraOffsets[1]);
	}

	function onFlxAnimFinish(name:String):Void
	{
		if (onAnimationFinish != null)
			onAnimationFinish(name);

		if (name == 'hey')
			isHeying = false;

		if (lockedAnim == name)
			lockedAnim = null;
	}

	override function update(elapsed:Float)
	{
		if (data == null)
		{
			super.update(elapsed);
			return;
		}

		if (stunned)
		{
			super.update(elapsed);
			return;
		}

		if (isHeying)
			heyTimer += elapsed;

		if (animation.curAnim != null)
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
				singTimer += elapsed;
			}
			else
			{
				holdTimer = 0;
				singTimer = 0;
			}

			if (!debugMode)
			{
				var missWindow = data.singDuration != null ? data.singDuration : 4;

				if (isPlayer && animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
				{
					playAnim('idle', true, false, 10);
				}

				if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
				{
					playAnim('deathLoop');
				}

				if (!isPlayer && data.danceIdle == true && animation.curAnim.name.startsWith('sing') && lockedAnim == null)
				{
					if (holdTimer >= Conductor.stepCrochet * missWindow * 0.001)
					{
						dance();
						holdTimer = 0;
					}
				}

				if (hasAnim('hairFall') && animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
					dance();
			}
		}

		super.update(elapsed);
	}

	public function dance():Void
	{
		if (debugMode || data == null || lockedAnim != null)
			return;

		if (data.danceIdle == true && data.danceSteps != null && data.danceSteps.length > 0)
		{
			if (hasAnim('hairBlow') && animation.curAnim != null && animation.curAnim.name.startsWith('hair'))
				return;

			danceIndex = (danceIndex + 1) % data.danceSteps.length;
			var nextAnim = data.danceSteps[danceIndex];

			if (hasAnim(nextAnim))
				playAnim(nextAnim);
		}
		else if (hasAnim('idle'))
		{
			playAnim('idle');
		}
	}

	public function sing(direction:String, ?miss:Bool = false):Void
	{
		var animName = 'sing' + direction.toUpperCase() + singSuffix + (miss ? 'miss' : '');

		if (hasAnim(animName))
			playAnim(animName, true);
	}

	public function hey():Void
	{
		if (data.heyEnabled != true || !hasAnim('hey'))
			return;

		isHeying = true;
		heyTimer = 0;
		lockedAnim = 'hey';
		playAnim('hey', true);

		var duration = data.heyDuration != null ? data.heyDuration : 0.6;

		new FlxTimer().start(duration, function(tmr:FlxTimer)
		{
			isHeying = false;
			lockedAnim = null;
			dance();
		});
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (!hasAnim(AnimName))
			return;

		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		if (data != null && data.danceSteps != null)
		{
			var idx = data.danceSteps.indexOf(AnimName);
			if (idx != -1)
				danceIndex = idx;
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}

	public function resetCharacter():Void
	{
		holdTimer = 0;
		singTimer = 0;
		heyTimer = 0;
		isHeying = false;
		lockedAnim = null;
		danceIndex = 0;
		applyStartingAnim();
	}

	override public function destroy():Void
	{
		onAnimationFinish = null;
		super.destroy();
	}
}
