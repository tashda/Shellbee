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
    // Light variety (Shellbee action-card coverage).
    "GL-SPI-206P", "BMCT-DZ", "GL-C-006", "GL-C-003P",
    "GL-H-001", "GL-C-006S", "3420-G", "LED2109G6",
    "GL-G-003P", "GL-C-006P", "LED1546G12", "QS-Zigbee-D02-TRIAC-LN",
    "QS-Zigbee-D02-TRIAC-2C-LN", "GL-C-007-1ID", "4256050-ZHAC", "4257050-ZHAC",
    // Switch variety (Shellbee action-card coverage).
    "BSP-FZ2", "BSP-FD", "BTH-RM230Z", "4256251-RZHAC",
    "PSM-29ZBSR", "4256050-RZHAC", "LLKZMK12LM", "X701A",
    "WS-USC01", "W564100", "AUT000069", "QBKG27LM",
    "BMCT-RZ", "4257050-RZHAC", "4200-C", "3200-fr",
    // Cover variety (Shellbee action-card coverage).
    "SCM-5ZBS", "S520567", "CP180335E-01", "CK-MG22-JLDJ-01(7015)",
    "ZNJLBL01LM", "QS-Zigbee-C01", "MB60L-ZG-ZT-TY", "E2102",
    "EPJ-ZB", "ZNCLDJ14LM", "HS2CM-N-DC", "E2103",
    "5128.10", "11830304", "TS130F_dual", "QS-Zigbee-C03",
    // Lock variety (Shellbee action-card coverage).
    "66492-001", "YRD426NRSC", "YRL256 TS", "99140-002",
    "99140-139", "YRD256HA20BP", "99140-031", "99100-045",
    "99100-006", "99120-021", "YAYRD256HA2619", "YRD652HA20BP",
    "YMF30", "YMF40/YDM4109+/YDF40", "YRD210-HA-605", "YRL-220L",
    // Climate variety (Shellbee action-card coverage).
    "CoZB_dha", "BTH-RM", "ZBHTR20WT", "BTH-RA",
    "SRTS-A01", "WT-A03E", "COZB0001", "TS0601_thermostat_thermosphere",
    "ME168_AVATTO", "3157100", "WV704R0A0902", "Icon2",
    "3156105", "Icon", "SLR1", "SLR1b",
    // Fan variety (Shellbee action-card coverage).
    "AC201",
    // Sensor variety (Shellbee action-card coverage).
    "8750001213", "WSDCGQ12LM", "ISW-ZPR1-WP13", "RADION TriTech ZB",
    "3323-G", "BSEN-W", "BSD-2", "WISZB-137",
    "HS3AQ", "AQSZB-110", "HS2AQ-EM", "FP1E",
    "KK-ES-J01W", "HS3CG", "BSIR-EZ", "BSEN-M",
    // Remote variety (Shellbee action-card coverage).
    "BSEN-C2", "8719514440937/8719514440999", "511.324", "SBRC-005B-B",
    "3400-D", "mTouch_Bryter", "SR-ZG9030F-PS", "BSEN-CV",
    "BSEN-C2D", "BHI-US", "KP-23EL-ZBS-ACE", "KEYZB-110",
    "SBTZB-110", "HS1RC-N", "HM1RC-2-E", "HS1RC-EM",
    // Generic variety (Shellbee action-card coverage).
    "SA100", "SRAC-23B-ZBSR", "QT-05M", "BMCT-SLZ",
    "Flower_Sensor_v2", "SLACKY_DIY_CO2_SENSOR_R02", "WS01", "WS90",
    "ZF24", "HM-722ESY-E Plus", "3328-G", "3310-G",
    "3315-Geu", "SS300", "SD-8SCZBS", "WLS-15ZBS",
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
