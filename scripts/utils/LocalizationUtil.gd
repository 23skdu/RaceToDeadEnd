extends RefCounted
class_name LocalizationUtil
## Lightweight localization helper for roadmap item 14.
##
## The project keeps all player-facing strings in one place so that the options
## screen can switch locale at runtime without reloading the current scene.
## Every key has an English fallback; programmatic Translation resources are
## registered for es/fr/de through TranslationServer.

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[String] = ["en", "es", "fr", "de"]

const LOCALE_NAMES: Dictionary = {
	"en": "English",
	"es": "Español",
	"fr": "Français",
	"de": "Deutsch",
}

# Locale -> { key -> translated string }. English doubles as the fallback map.
const STRINGS: Dictionary = {
	"en": {
		"R2DE_OPTIONS_TITLE": "OPTIONS",
		"R2DE_GARAGE_TITLE": "GARAGE",
		"R2DE_CREDITS_PREFIX": "CREDITS: ",
		"R2DE_AUDIO_TAB": "Audio",
		"R2DE_INPUT_TAB": "Input",
		"R2DE_ACCESSIBILITY_TAB": "Accessibility",
		"R2DE_LEADERBOARD_TAB": "Leaderboard",
		"R2DE_LOCALE_LABEL": "Language",
		"R2DE_HIGH_CONTRAST": "High contrast",
		"R2DE_COLORBLIND_MODE": "Colorblind mode",
		"R2DE_REDUCE_MOTION": "Reduced motion",
		"R2DE_LANGUAGE": "Language",
		"R2DE_FEATURES_HEADER": "FEATURES",
		"R2DE_FEATURE_boss_animations": "Boss animations",
		"R2DE_FEATURE_themed_ui": "Themed UI",
		"R2DE_FEATURE_localization": "Localization",
		"R2DE_FEATURE_online_leaderboard": "Online leaderboard",
		"R2DE_COLORBLIND_none": "None",
		"R2DE_COLORBLIND_protanopia": "Protanopia",
		"R2DE_COLORBLIND_deuteranopia": "Deuteranopia",
		"R2DE_COLORBLIND_tritanopia": "Tritanopia",
		"R2DE_LEADERBOARD_ENDPOINT": "Leaderboard endpoint",
		"R2DE_PLAYER_NAME": "Player name",
		"R2DE_FETCH_SCORES": "FETCH SCORES",
		"R2DE_SUBMIT_SCORE": "SUBMIT SCORE",
		"R2DE_SCORES_HEADER": "TOP SCORES",
		"R2DE_LOADING_SCORES": "Loading scores...",
		"R2DE_SCORE_SUBMITTED": "Score submitted",
		"R2DE_SCORE_NOT_SUBMITTED": "Score saved locally",
		"R2DE_LEADERBOARD_FAILED": "Offline - showing local scores",
		"R2DE_NO_SCORES": "No scores yet",
		"R2DE_RESTART": "RESTART",
		"R2DE_BACK": "BACK",
		"R2DE_SKIN_UNLOCKED": "Unlocked",
		"R2DE_SKIN_LOCKED": "Locked",
		"R2DE_SELECT_SKIN": "SELECT SKIN",
		"R2DE_INTERCEPTOR_SKINS": "INTERCEPTOR SKINS",
		"R2DE_CUSTOM_PACKS": "CUSTOM CONTENT PACKS",
		"R2DE_NO_PACKS": "No custom content packs installed.",
		"R2DE_PREVIEW_LABEL": "PREVIEW",
		"R2DE_UNLOCK_HINT_PREFIX": "Unlock: ",
	},
	"es": {
		"R2DE_OPTIONS_TITLE": "OPCIONES",
		"R2DE_GARAGE_TITLE": "GARAJE",
		"R2DE_CREDITS_PREFIX": "CRÉDITOS: ",
		"R2DE_AUDIO_TAB": "Audio",
		"R2DE_INPUT_TAB": "Controles",
		"R2DE_ACCESSIBILITY_TAB": "Accesibilidad",
		"R2DE_LEADERBOARD_TAB": "Clasificación",
		"R2DE_LOCALE_LABEL": "Idioma",
		"R2DE_HIGH_CONTRAST": "Alto contraste",
		"R2DE_COLORBLIND_MODE": "Modo daltónico",
		"R2DE_REDUCE_MOTION": "Movimiento reducido",
		"R2DE_LANGUAGE": "Idioma",
		"R2DE_FEATURES_HEADER": "FUNCIONES",
		"R2DE_FEATURE_boss_animations": "Animaciones de jefes",
		"R2DE_FEATURE_themed_ui": "Interfaz temática",
		"R2DE_FEATURE_localization": "Localización",
		"R2DE_FEATURE_online_leaderboard": "Clasificación en línea",
		"R2DE_COLORBLIND_none": "Ninguno",
		"R2DE_COLORBLIND_protanopia": "Protanopía",
		"R2DE_COLORBLIND_deuteranopia": "Deuteranopía",
		"R2DE_COLORBLIND_tritanopia": "Tritanopía",
		"R2DE_LEADERBOARD_ENDPOINT": "Servidor de clasificación",
		"R2DE_PLAYER_NAME": "Nombre del jugador",
		"R2DE_FETCH_SCORES": "VER PUNTUACIONES",
		"R2DE_SUBMIT_SCORE": "ENVIAR PUNTUACIÓN",
		"R2DE_SCORES_HEADER": "MEJORES PUNTUACIONES",
		"R2DE_LOADING_SCORES": "Cargando puntuaciones...",
		"R2DE_SCORE_SUBMITTED": "Puntuación enviada",
		"R2DE_SCORE_NOT_SUBMITTED": "Puntuación guardada localmente",
		"R2DE_LEADERBOARD_FAILED": "Sin conexión - puntuaciones locales",
		"R2DE_NO_SCORES": "Aún no hay puntuaciones",
		"R2DE_RESTART": "REINICIAR",
		"R2DE_BACK": "VOLVER",
		"R2DE_SKIN_UNLOCKED": "Desbloqueado",
		"R2DE_SKIN_LOCKED": "Bloqueado",
		"R2DE_SELECT_SKIN": "SELECCIONAR SKIN",
		"R2DE_INTERCEPTOR_SKINS": "SKINS DEL INTERCEPTOR",
		"R2DE_CUSTOM_PACKS": "PAQUETES PERSONALIZADOS",
		"R2DE_NO_PACKS": "No hay paquetes personalizados instalados.",
		"R2DE_PREVIEW_LABEL": "VISTA PREVIA",
		"R2DE_UNLOCK_HINT_PREFIX": "Desbloqueo: ",
	},
	"fr": {
		"R2DE_OPTIONS_TITLE": "OPTIONS",
		"R2DE_GARAGE_TITLE": "GARAGE",
		"R2DE_CREDITS_PREFIX": "CRÉDITS : ",
		"R2DE_AUDIO_TAB": "Audio",
		"R2DE_INPUT_TAB": "Commandes",
		"R2DE_ACCESSIBILITY_TAB": "Accessibilité",
		"R2DE_LEADERBOARD_TAB": "Classement",
		"R2DE_LOCALE_LABEL": "Langue",
		"R2DE_HIGH_CONTRAST": "Contraste élevé",
		"R2DE_COLORBLIND_MODE": "Mode daltonien",
		"R2DE_REDUCE_MOTION": "Mouvement réduit",
		"R2DE_LANGUAGE": "Langue",
		"R2DE_FEATURES_HEADER": "FONCTIONNALITÉS",
		"R2DE_FEATURE_boss_animations": "Animations des boss",
		"R2DE_FEATURE_themed_ui": "Interface thématique",
		"R2DE_FEATURE_localization": "Localisation",
		"R2DE_FEATURE_online_leaderboard": "Classement en ligne",
		"R2DE_COLORBLIND_none": "Aucun",
		"R2DE_COLORBLIND_protanopia": "Protanopie",
		"R2DE_COLORBLIND_deuteranopia": "Deutéranopie",
		"R2DE_COLORBLIND_tritanopia": "Tritanopie",
		"R2DE_LEADERBOARD_ENDPOINT": "Serveur de classement",
		"R2DE_PLAYER_NAME": "Nom du joueur",
		"R2DE_FETCH_SCORES": "VOIR LES SCORES",
		"R2DE_SUBMIT_SCORE": "ENVOYER LE SCORE",
		"R2DE_SCORES_HEADER": "MEILLEURS SCORES",
		"R2DE_LOADING_SCORES": "Chargement des scores...",
		"R2DE_SCORE_SUBMITTED": "Score envoyé",
		"R2DE_SCORE_NOT_SUBMITTED": "Score enregistré localement",
		"R2DE_LEADERBOARD_FAILED": "Hors ligne - scores locaux",
		"R2DE_NO_SCORES": "Aucun score pour l'instant",
		"R2DE_RESTART": "RECOMMENCER",
		"R2DE_BACK": "RETOUR",
		"R2DE_SKIN_UNLOCKED": "Débloqué",
		"R2DE_SKIN_LOCKED": "Verrouillé",
		"R2DE_SELECT_SKIN": "CHOISIR UN SKIN",
		"R2DE_INTERCEPTOR_SKINS": "SKINS DE L'INTERCEPTOR",
		"R2DE_CUSTOM_PACKS": "PACKS PERSONNALISÉS",
		"R2DE_NO_PACKS": "Aucun pack personnalisé installé.",
		"R2DE_PREVIEW_LABEL": "APERÇU",
		"R2DE_UNLOCK_HINT_PREFIX": "Débloquer : ",
	},
	"de": {
		"R2DE_OPTIONS_TITLE": "OPTIONEN",
		"R2DE_GARAGE_TITLE": "GARAGE",
		"R2DE_CREDITS_PREFIX": "GUTHABEN: ",
		"R2DE_AUDIO_TAB": "Audio",
		"R2DE_INPUT_TAB": "Steuerung",
		"R2DE_ACCESSIBILITY_TAB": "Barrierefreiheit",
		"R2DE_LEADERBOARD_TAB": "Bestenliste",
		"R2DE_LOCALE_LABEL": "Sprache",
		"R2DE_HIGH_CONTRAST": "Hoher Kontrast",
		"R2DE_COLORBLIND_MODE": "Farbenblind-Modus",
		"R2DE_REDUCE_MOTION": "Reduzierte Bewegung",
		"R2DE_LANGUAGE": "Sprache",
		"R2DE_FEATURES_HEADER": "FUNKTIONEN",
		"R2DE_FEATURE_boss_animations": "Boss-Animationen",
		"R2DE_FEATURE_themed_ui": "Thematische Oberfläche",
		"R2DE_FEATURE_localization": "Lokalisierung",
		"R2DE_FEATURE_online_leaderboard": "Online-Bestenliste",
		"R2DE_COLORBLIND_none": "Keiner",
		"R2DE_COLORBLIND_protanopia": "Protanopie",
		"R2DE_COLORBLIND_deuteranopia": "Deuteranopie",
		"R2DE_COLORBLIND_tritanopia": "Tritanopie",
		"R2DE_LEADERBOARD_ENDPOINT": "Bestenliste-Endpunkt",
		"R2DE_PLAYER_NAME": "Spielername",
		"R2DE_FETCH_SCORES": "PUNKTE LADEN",
		"R2DE_SUBMIT_SCORE": "PUNKT SENDEN",
		"R2DE_SCORES_HEADER": "BESTE PUNKTE",
		"R2DE_LOADING_SCORES": "Punkte werden geladen...",
		"R2DE_SCORE_SUBMITTED": "Punkt gesendet",
		"R2DE_SCORE_NOT_SUBMITTED": "Punkt lokal gespeichert",
		"R2DE_LEADERBOARD_FAILED": "Offline - lokale Punkte",
		"R2DE_NO_SCORES": "Noch keine Punkte",
		"R2DE_RESTART": "NEUSTART",
		"R2DE_BACK": "ZURÜCK",
		"R2DE_SKIN_UNLOCKED": "Freigeschaltet",
		"R2DE_SKIN_LOCKED": "Gesperrt",
		"R2DE_SELECT_SKIN": "SKIN AUSWÄHLEN",
		"R2DE_INTERCEPTOR_SKINS": "INTERCEPTOR-SKINS",
		"R2DE_CUSTOM_PACKS": "BENUTZERDEFINIERTE PAKETE",
		"R2DE_NO_PACKS": "Keine benutzerdefinierten Pakete installiert.",
		"R2DE_PREVIEW_LABEL": "VORSCHAU",
		"R2DE_UNLOCK_HINT_PREFIX": "Freischalten: ",
	},
}

const SKIN_NAME_KEYS: Dictionary = {
	"default": "R2DE_SKIN_DEFAULT",
	"crimson_viper": "R2DE_SKIN_CRIMSON_VIPER",
	"toxic_volt": "R2DE_SKIN_TOXIC_VOLT",
	"solar_chrome": "R2DE_SKIN_SOLAR_CHROME",
	"urban_camo": "R2DE_SKIN_URBAN_CAMO",
	"nitro_phantom": "R2DE_SKIN_NITRO_PHANTOM",
	"ghost_protocol": "R2DE_SKIN_GHOST_PROTOCOL",
	"solar_flare": "R2DE_SKIN_SOLAR_FLARE",
	"neon_drifter": "R2DE_SKIN_NEON_DRIFTER",
	"apex_predator": "R2DE_SKIN_APEX_PREDATOR",
}

const SKIN_NAMES: Dictionary = {
	"en": {
		"R2DE_SKIN_DEFAULT": "Interceptor Classic",
		"R2DE_SKIN_CRIMSON_VIPER": "Crimson Viper",
		"R2DE_SKIN_TOXIC_VOLT": "Toxic Volt",
		"R2DE_SKIN_SOLAR_CHROME": "Solar Chrome",
		"R2DE_SKIN_URBAN_CAMO": "Urban Camo",
		"R2DE_SKIN_NITRO_PHANTOM": "Nitro Phantom",
		"R2DE_SKIN_GHOST_PROTOCOL": "Ghost Protocol",
		"R2DE_SKIN_SOLAR_FLARE": "Solar Flare",
		"R2DE_SKIN_NEON_DRIFTER": "Neon Drifter",
		"R2DE_SKIN_APEX_PREDATOR": "Apex Predator",
	},
	"es": {
		"R2DE_SKIN_DEFAULT": "Interceptor Clásico",
		"R2DE_SKIN_CRIMSON_VIPER": "Víbora Carmesí",
		"R2DE_SKIN_TOXIC_VOLT": "Voltaje Tóxico",
		"R2DE_SKIN_SOLAR_CHROME": "Cromo Solar",
		"R2DE_SKIN_URBAN_CAMO": "Camuflaje urbano",
		"R2DE_SKIN_NITRO_PHANTOM": "Nitro Fantasma",
		"R2DE_SKIN_GHOST_PROTOCOL": "Protocolo Fantasma",
		"R2DE_SKIN_SOLAR_FLARE": "Llamarada solar",
		"R2DE_SKIN_NEON_DRIFTER": "Deriva neón",
		"R2DE_SKIN_APEX_PREDATOR": "Depredador supremo",
	},
	"fr": {
		"R2DE_SKIN_DEFAULT": "Interceptor Classique",
		"R2DE_SKIN_CRIMSON_VIPER": "Vipère Cramoisie",
		"R2DE_SKIN_TOXIC_VOLT": "Voltage Toxique",
		"R2DE_SKIN_SOLAR_CHROME": "Chrome Solaire",
		"R2DE_SKIN_URBAN_CAMO": "Camouflage urbain",
		"R2DE_SKIN_NITRO_PHANTOM": "Phantom Nitro",
		"R2DE_SKIN_GHOST_PROTOCOL": "Protocole Fantôme",
		"R2DE_SKIN_SOLAR_FLARE": "Éruption solaire",
		"R2DE_SKIN_NEON_DRIFTER": "Dérive néon",
		"R2DE_SKIN_APEX_PREDATOR": "Prédateur suprême",
	},
	"de": {
		"R2DE_SKIN_DEFAULT": "Interceptor Klassisch",
		"R2DE_SKIN_CRIMSON_VIPER": "Scharlachviper",
		"R2DE_SKIN_TOXIC_VOLT": "Giftvolt",
		"R2DE_SKIN_SOLAR_CHROME": "Solarchrom",
		"R2DE_SKIN_URBAN_CAMO": "Urban-Camo",
		"R2DE_SKIN_NITRO_PHANTOM": "Nitro-Phantom",
		"R2DE_SKIN_GHOST_PROTOCOL": "Geisterprotokoll",
		"R2DE_SKIN_SOLAR_FLARE": "Solarflare",
		"R2DE_SKIN_NEON_DRIFTER": "Neon-Drifter",
		"R2DE_SKIN_APEX_PREDATOR": "Apex-Raubtier",
	},
}

static var _translations: Dictionary = {}


func _init() -> void:
	_register_translations()


static func normalized_locale(locale: String) -> String:
	var code: String = locale.strip_edges().replace("-", "_")
	if code.is_empty():
		return DEFAULT_LOCALE
	var base: String = code.split("_")[0]
	if SUPPORTED_LOCALES.has(base):
		return base
	return DEFAULT_LOCALE


static func locale_name(locale: String) -> String:
	var code: String = normalized_locale(locale)
	return String(LOCALE_NAMES.get(code, code))


static func t(key: String, fallback: String = "") -> String:
	var locale: String = TranslationServer.get_locale()
	var code: String = normalized_locale(locale)
	var table: Dictionary = STRINGS.get(code, {})
	if table.has(key):
		return String(table[key])
	var skin_table: Dictionary = SKIN_NAMES.get(code, {})
	if skin_table.has(key):
		return String(skin_table[key])
	var english: Dictionary = STRINGS.get(DEFAULT_LOCALE, {})
	if english.has(key):
		return String(english[key])
	var english_skin: Dictionary = SKIN_NAMES.get(DEFAULT_LOCALE, {})
	if english_skin.has(key):
		return String(english_skin[key])
	if not fallback.is_empty():
		return fallback
	return key


static func skin_name(skin_id: String) -> String:
	var key: String = String(SKIN_NAME_KEYS.get(skin_id, ""))
	if key.is_empty():
		return skin_id
	return t(key, skin_id)


func apply_locale(locale: String) -> String:
	var code: String = normalized_locale(locale)
	TranslationServer.set_locale(code)
	return code


func _register_translations() -> void:
	for locale in SUPPORTED_LOCALES:
		if _translations.has(locale):
			continue
		var translation := Translation.new()
		translation.locale = locale
		var ui_table: Dictionary = STRINGS.get(locale, {})
		for key in ui_table:
			translation.add_message(String(key), String(ui_table[key]))
		var skin_table: Dictionary = SKIN_NAMES.get(locale, {})
		for key in skin_table:
			translation.add_message(String(key), String(skin_table[key]))
		_translations[locale] = translation
		TranslationServer.add_translation(translation)
