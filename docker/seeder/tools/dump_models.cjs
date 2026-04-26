#!/usr/bin/env node
/*
 * Dump zigbee-herdsman-converters definitions for the models referenced in
 * fixtures.py to a single JSON file the Python seeder can load.
 *
 * Usage:
 *   cd docker/seeder/tools
 *   npm install zigbee-herdsman-converters
 *   node dump_models.cjs > ../models.json
 *
 * Re-run whenever you add a model to MODELS or bump zhc.
 */

const fs = require("fs");
const path = require("path");
const zhc = require("zigbee-herdsman-converters");

const MODELS = [
    "014G2461", "324131092621", "9290012573A", "9290019758",
    "9290024896",
    "BE468", "DJT11LM", "E1524/E1810", "E1525/E1745",
    "E160x/E170x/E190x", "E1743", "E1757", "E1926", "E2007",
    "GL-C-008-1ID", "GZCGQ01LM", "HS2WD-E", "LDSENK09",
    "LED1545G12", "LED1836G9", "LED1949C5", "MCCGQ11LM",
    "QBKG11LM", "QBKG12LM", "RTCGQ11LM", "RTCZCGQ11LM",
    "SMSZB-120", "SPZB0001", "TS011F_plug_1", "VOCKQJK11LM",
    "WSDCGQ11LM", "YRD226HA2619", "Z3-1BRL", "ZNXNKG02LM",
    // Extra fan variety for UI testing.
    "FanBee", "99432", "VZM35-SN", "VZM36", "SSWF01G",
    "ZC0101", "AC221", "PCT504", "41ECSFWMZ-VW",
    "_TZE284_z5jz7wpo",
];

const devicesDir = path.join(
    require.resolve("zigbee-herdsman-converters"),
    "..", "devices",
);

const wanted = new Set(MODELS);
const found = {};

for (const file of fs.readdirSync(devicesDir)) {
    if (!file.endsWith(".js")) continue;
    let mod;
    try {
        mod = require(path.join(devicesDir, file));
    } catch (e) {
        continue;
    }
    if (!Array.isArray(mod.definitions)) continue;
    for (const def of mod.definitions) {
        if (!wanted.has(def.model)) continue;
        const prep = zhc.prepareDefinition(def);
        let exposes = prep.exposes;
        if (typeof exposes === "function") {
            exposes = exposes({isDummyDevice: true, endpoints: []}, {});
        }
        let options = prep.options || [];
        // strip non-serialisable bits (functions, internal symbols)
        const serialisable = JSON.parse(JSON.stringify({
            model: prep.model,
            vendor: prep.vendor,
            description: prep.description,
            zigbeeModel: prep.zigbeeModel || [],
            exposes,
            options,
            meta: prep.meta || {},
        }));
        found[def.model] = serialisable;
    }
}

const missing = MODELS.filter(m => !(m in found));
if (missing.length) {
    console.error("MISSING:", missing.join(", "));
    process.exit(1);
}

process.stdout.write(JSON.stringify(found, null, 2));
console.error(`OK: dumped ${Object.keys(found).length} models`);
