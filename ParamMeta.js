// Human-facing copy for the settings panel: display labels, value
// formatting, and a one-line description per parameter.
//
// This is deliberately NOT part of params.schema.json. That file is a
// mechanical extraction of each animation's parameter definitions and
// can be regenerated at any time; hand-written copy living there would
// be lost on the next regeneration.

// Descriptions are keyed by parameter name, since names are reused across
// animations (`speed` appears in 27 of them). Where a name genuinely means
// something different in one animation, OVERRIDES wins.
var DESCRIPTIONS = {
  atmosphereColor: "Tint of the hazy shell drawn around the planet's edge.",
  atmosphereDensity: "How thick the atmosphere looks. 0 removes it entirely.",
  atmosphereDirection: "Which way the cloud bands drift. Negative reverses them.",
  atmosphereTurbulence: "How much the cloud bands churn and break up as they drift.",
  aurora: "Draw shimmering polar lights over the planet's night side.",
  autoJump: "Automatically fly to a new area of the fractal instead of holding one view.",
  bands: "Number of separate curtains of light in the sky.",
  bootCycle: "Replay the fake boot-up sequence each time the deck restarts.",
  brightness: "Overall luminosity of the light curtains.",
  bubbleRate: "How often bubbles rise from the tank floor.",
  cellSize: "Pixel size of one cell. Smaller cells mean a larger, denser grid.",
  chaos: "Overall instability. Higher values distort the field more violently.",
  charset: "Which characters are used to shade the fractal, darkest to lightest.",
  chimeCount: "Number of hanging tubes in the set.",
  cohesion: "How strongly each bird steers toward the centre of its flock.",
  complexity: "Number of layered harmonics in the traced curve.",
  condensation: "How much moisture beads and runs on the inside of the glass.",
  corruption: "How much the terminal output glitches and garbles.",
  corruptionRate: "How frequently fresh corruption is injected into the field.",
  crackleIntensity: "How often the fire pops and throws sparks.",
  cyclePeriod: "Seconds spent on each traced shape before moving to the next.",
  cycleTime: "Seconds for one full cycle.",
  density: "How much of the scene is filled.",
  dewDensity: "How many dew droplets cling to the threads.",
  diffusion: "How quickly the dye spreads outward through the fluid.",
  diskSize: "Radius of the glowing accretion disk around the hole.",
  dissolveStyle: "How the finished mandala is swept away before being redrawn.",
  doublePendulum: "Hang each chime from a second pivot, producing chaotic swings.",
  driftCurrents: "Strength of the water currents pushing the jellyfish around.",
  dustDensity: "How many dust motes drift through the lamplight.",
  dyeFade: "How slowly the dye fades. Higher values leave longer-lived trails.",
  emberRate: "How many embers lift off the fire and float upward.",
  episode: "Which title crawl to show. -1 picks a different one at random each run.",
  eruptionRate: "How frequently the volcano throws a fresh burst of lava.",
  fading: "Let older pipe segments dim behind the advancing tip.",
  faunaRate: "How much animal life appears and moves through the terrarium.",
  feedRate: "How often food is dropped for the fish to chase.",
  fishCount: "Number of fish swimming in the tank.",
  flameHeight: "How far the flames reach above the logs.",
  flickerIntensity: "How unsteadily the tubes glow, like worn neon.",
  floaterFreq: "How often objects drift across the face of the moon.",
  flockSize: "Number of birds in the flock.",
  flowDensity: "How much water is falling. Higher values make a fuller sheet.",
  flowIntensity: "How fast and far the lava flows run down the slope.",
  forestSilhouette: "Draw a treeline behind the campfire.",
  glowColor: "Colour of the gas discharge inside the tubes.",
  glowIntensity: "Strength of the soft halo around bright areas.",
  growthCycle: "Loop replants and regrows the terrarium; static holds it fully grown.",
  gustFrequency: "How often a gust arrives to set the chimes moving.",
  holdTime: "Seconds the finished piece is held on screen before it is redrawn.",
  inclination: "Viewing angle of the disk. 0 is edge-on, 1 is face-on.",
  intensity: "Overall strength of the storm.",
  jellyfishCount: "Number of jellyfish drifting in frame.",
  jets: "Draw the relativistic jets firing from the hole's poles.",
  kelpDensity: "How thickly kelp grows along the back of the tank.",
  lampGlow: "Brightness of the lamp lighting the turntable.",
  leafDensity: "How thickly leaves fill the branches.",
  lightning: "How frequently lightning strikes.",
  maxIter: "Detail limit for the fractal. Higher resolves finer structure but costs more.",
  mistIntensity: "How much spray hangs in the air at the base of the fall.",
  moonGlow: "Brightness of the moonlight falling across the web.",
  morphTime: "Seconds spent morphing from one shape into the next.",
  noise: "Amount of signal noise jittering the trace.",
  pacing: "Overall tempo of the scene, from brisk to glacial.",
  palette: "Colour scheme used to draw the animation.",
  pendulumCount: "Number of pendulums in the row.",
  phosphorDecay: "How slowly the trace fades, like screen phosphor. Higher leaves longer tails.",
  pitch: "Tuning of the chimes. Higher values ring brighter.",
  planetColor: "Surface palette of the planet.",
  planetSize: "How much of the frame the planet fills.",
  plantDensity: "How many plants grow inside the terrarium.",
  poisoningSpeed: "How fast the cathode-poisoning routine cycles the unused digits.",
  predator: "Introduce a hunter that scatters the flock.",
  predatorRate: "How often a predator appears to hunt.",
  predatorSpeed: "How fast the predator closes on the flock.",
  preyRate: "How often prey blunders into the web.",
  rainbow: "Cast a rainbow through the mist at the base of the fall.",
  randomization: "How much each smoke plume varies from the last.",
  reseedMode: "Which starting pattern is used when the board is reseeded.",
  resolution: "Simulation grid resolution. Higher is finer but more demanding.",
  rings: "Draw a ring system around the planet.",
  rotationSpeed: "How fast the camera orbits the attractor.",
  scanBands: "Number of horizontal scan bands tearing across the field.",
  scrollSpeed: "How fast text scrolls up the terminal.",
  seasonTime: "Seconds for the terrarium to pass through a full year of seasons.",
  separation: "How hard each bird steers away from its neighbours to avoid crowding.",
  shapeSet: "Which family of shapes the trace cycles through.",
  showSeconds: "Display a seconds pair alongside hours and minutes.",
  smokeColor: "Tint of the rising smoke.",
  smokeDensity: "How thick and opaque the smoke is.",
  smokeLifespan: "How long each wisp of smoke lingers before dissipating.",
  soundType: "Material the chimes are struck from, which sets their timbre.",
  spawnRate: "How often a new pipe starts growing.",
  speed: "Overall animation speed.",
  stars: "Number of background stars in the sky.",
  swingAngle: "How far the pendulums swing from vertical.",
  symmetry: "Number of mirrored segments in the mandala.",
  terminalStyle: "Phosphor colour of the terminal.",
  trailLength: "How many points of the path stay visible behind the moving tip.",
  tubeColons: "Show lit colons between the tube pairs.",
  tubeStyle: "Shape of the tube housings.",
  viscosity: "How thick the fluid is. Higher values damp motion faster.",
  webSway: "How much the web flexes in the breeze.",
  wind: "Direction and strength of the wind. Negative blows the other way.",
  windDirection: "Which way the draught pushes the smoke. Negative reverses it.",
  windSpeed: "How strongly the draught carries the smoke sideways.",
  windStrength: "How hard the wind pushes the chimes."
};

// Only for names whose meaning genuinely shifts between animations.
var OVERRIDES = {
  bonsai: {
    speed: "How quickly time passes for the tree: growth, seasons and days.",
    palette: "The kind of tree: juniper (evergreen), maple, sakura, flowering cherry, wisteria, or sumi-e ink.",
    leafDensity: "How full and broad the foliage pads grow.",
    holdTime: "Seconds the mature tree is kept before it returns to mist and a new seed falls.",
    style: "Bonsai style: formal upright, informal upright, slanting, cascade, literati, windswept — or a different one each life.",
    seasonTime: "Seconds per season. One day passes each season."
  },
  crawl: {
    speed: "How fast the text crawls up the screen."
  },
  gameoflife: {
    speed: "How quickly generations advance.",
    density: "Fraction of cells alive in the starting board."
  },
  pipes: {
    density: "How many pipes grow through the scene at once."
  },
  glitch_field: {
    density: "How much of the frame is covered in glitching characters."
  },
  mandelbrot: {
    speed: "How fast the view zooms into the fractal."
  },
  terrarium: {
    cycleTime: "Minutes for one full day-night cycle. 0 holds a fixed time of day."
  },
  aquarium: {
    cycleTime: "Minutes for one full day-night cycle. 0 holds a fixed time of day."
  },
  boids: {
    cycleTime: "Minutes for one full day, dusk murmuration included. 0 holds a fixed late afternoon.",
    palette: "Season: summer meadow, falling autumn leaves, winter snow, or monochrome.",
    flockSize: "Number of resident starlings. More arrive to join the roost at dusk.",
    predator: "A falcon that circles and stoops on the flock.",
    predatorSpeed: "How fast the falcon dives."
  },
  pendulum_wave: {
    cycleTime: "Seconds before the pendulums realign into their starting row."
  },
  attractor: {
    cycleTime: "Seconds spent on one attractor before switching to another."
  },
  sandmandala: {
    speed: "How quickly the monks lay down new sand."
  }
};

// "leafDensity" -> "Leaf Density".
function formatLabel(key) {
  var name = String(key === null || key === undefined ? "" : key);
  if (!name) return "";
  return name
    .replace(/_/g, " ")
    .replace(/([A-Z])/g, " $1")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/(^|\s)\S/g, function (char) { return char.toUpperCase(); });
}

// Whole numbers render bare; fractions get 2dp so a slider readout does not
// jitter between 0.7000000000000001 and 0.7.
function formatValue(value) {
  if (typeof value === "number" && isFinite(value)) {
    return Number.isInteger(value) ? String(value) : value.toFixed(2);
  }
  return String(value === null || value === undefined ? "" : value);
}

// Delays are stored in seconds, but "150" tells the user much less than
// "2m 30s" when they are choosing how long the screen sits idle.
function formatDuration(seconds) {
  var total = Math.max(0, Math.round(Number(seconds) || 0));
  var hours = Math.floor(total / 3600);
  var minutes = Math.floor((total % 3600) / 60);
  var secs = total % 60;

  var parts = [];
  if (hours > 0) parts.push(hours + "h");
  if (minutes > 0) parts.push(minutes + "m");
  if (secs > 0 || parts.length === 0) parts.push(secs + "s");
  return parts.join(" ");
}

// Several params are booleans wearing another type: mostly `select` over
// [0, 1], but `bootCycle` is a range of 0..1 with step 1. Both deserve a
// real toggle rather than a dropdown reading "0" / "1".
function isBooleanParam(spec) {
  if (!spec || typeof spec !== "object") return false;

  if (spec.type === "select") {
    var options = spec.options;
    if (!Array.isArray(options) || options.length !== 2) return false;
    var sorted = options.slice().sort();
    return Number(sorted[0]) === 0 && Number(sorted[1]) === 1
      && typeof options[0] === "number" && typeof options[1] === "number";
  }

  if (spec.type === "range") {
    return Number(spec.min) === 0 && Number(spec.max) === 1 && Number(spec.step) === 1;
  }

  return false;
}

// Dropdowns hand back strings. Writing "8" where the animation expects 8
// (symmetry) or "1" where it expects 1 (jets) silently breaks it, so match
// the type of the schema's own default.
function coerceSelectValue(value, sample) {
  return typeof sample === "number" ? Number(value) : value;
}

function describe(paramName, animationName) {
  var key = String(paramName || "");
  var animation = String(animationName || "");
  var override = OVERRIDES[animation];
  if (override && override[key]) return override[key];
  return DESCRIPTIONS[key] || "";
}

if (typeof module !== "undefined") {
  module.exports = {
    formatLabel: formatLabel,
    formatValue: formatValue,
    formatDuration: formatDuration,
    isBooleanParam: isBooleanParam,
    coerceSelectValue: coerceSelectValue,
    describe: describe
  };
}
