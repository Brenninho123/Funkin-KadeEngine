package funkin;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.media.Sound;
import openfl.system.System;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String;
	static var currentModDirectory:String = "";

	public static var localTrackedAssets:Array<String> = [];
	static var currentTrackedSounds:Map<String, Sound> = new Map<String, Sound>();
	static var currentTrackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	static public function setCurrentMod(name:String)
	{
		currentModDirectory = name;
	}

	static public function clearStoredMemory(?cleanUnused:Bool = false)
	{
		for (key in currentTrackedSounds.keys())
		{
			if (currentTrackedSounds.get(key) != null && (localTrackedAssets.contains(key) || cleanUnused))
			{
				OpenFlAssets.cache.removeSound(key);
				currentTrackedSounds.remove(key);
			}
		}

		for (key in currentTrackedGraphics.keys())
		{
			if (currentTrackedGraphics.get(key) != null && (localTrackedAssets.contains(key) || cleanUnused))
			{
				OpenFlAssets.cache.removeBitmapData(key);
				FlxG.bitmap.remove(currentTrackedGraphics.get(key));
				currentTrackedGraphics.remove(key);
			}
		}

		localTrackedAssets = [];
		System.gc();
	}

	static function getModPath(file:String)
	{
		if (currentModDirectory != null && currentModDirectory.length > 0)
			return 'mods/$currentModDirectory/$file';

		return 'mods/$file';
	}

	static function modsAssetExists(file:String)
	{
		return sys.FileSystem.exists(getModPath(file));
	}

	static function getPath(file:String, type:AssetType, library:Null<String>)
	{
		#if MODS_ALLOWED
		var modPath = getModPath(file);
		if (modsAssetExists(file))
			return modPath;
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath = getLibraryPathForce(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return getPath('data/$key.lua', TEXT, library);
	}

	inline static public function luaImage(key:String, ?library:String)
	{
		return getPath('data/$key.png', IMAGE, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String)
	{
		var path = getPath('sounds/$key.$SOUND_EXT', SOUND, library);

		if (!currentTrackedSounds.exists(path))
			currentTrackedSounds.set(path, cacheSound(path));

		localTrackedAssets.push(path);
		return currentTrackedSounds.get(path);
	}

	static function cacheSound(path:String):Sound
	{
		#if MODS_ALLOWED
		if (sys.FileSystem.exists(path))
			return Sound.fromFile(path);
		#end

		return OpenFlAssets.getSound(path, true);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	static public function music(key:String, ?library:String)
	{
		var path = getPath('music/$key.$SOUND_EXT', MUSIC, library);

		if (!currentTrackedSounds.exists(path))
			currentTrackedSounds.set(path, cacheSound(path));

		localTrackedAssets.push(path);
		return currentTrackedSounds.get(path);
	}

	inline static public function voices(song:String)
	{
		var songLowercase = formatSongName(song);
		return 'songs:assets/songs/${songLowercase}/Voices.$SOUND_EXT';
	}

	inline static public function inst(song:String)
	{
		var songLowercase = formatSongName(song);
		return 'songs:assets/songs/${songLowercase}/Inst.$SOUND_EXT';
	}

	static function formatSongName(song:String):String
	{
		var songLowercase = StringTools.replace(song, " ", "-").toLowerCase();
		switch (songLowercase)
		{
			case 'dad-battle': songLowercase = 'dadbattle';
			case 'philly-nice': songLowercase = 'philly';
		}
		return songLowercase;
	}

	static public function image(key:String, ?library:String):FlxGraphic
	{
		var path = getPath('images/$key.png', IMAGE, library);

		if (!currentTrackedGraphics.exists(path))
		{
			var bitmap = #if MODS_ALLOWED sys.FileSystem.exists(path) ? openfl.display.BitmapData.fromFile(path) : OpenFlAssets.getBitmapData(path) #else OpenFlAssets.getBitmapData(path) #end;
			var graphic = FlxGraphic.fromBitmapData(bitmap, false, path);
			graphic.persist = true;
			currentTrackedGraphics.set(path, graphic);
		}

		localTrackedAssets.push(path);
		return currentTrackedGraphics.get(path);
	}

	inline static public function font(key:String)
	{
		return 'assets/fonts/$key';
	}

	static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', TEXT, library));
	}

	static public function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', TEXT, library));
	}
}
