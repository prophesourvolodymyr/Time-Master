const escape = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function node(value, indent) {
  const pad = "\t".repeat(indent);
  if (value instanceof Date) return `${pad}<date>${value.toISOString().replace(/\.\d{3}Z$/, "Z")}</date>`;
  if (value && typeof value === "object" && Buffer.isBuffer(value.data)) return `${pad}<data>${value.data.toString("base64")}</data>`;
  if (Array.isArray(value)) return `${pad}<array>\n${value.map((item) => node(item, indent + 1)).join("\n")}\n${pad}</array>`;
  if (typeof value === "boolean") return `${pad}<${value}/>`;
  if (typeof value === "number") return Number.isInteger(value) ? `${pad}<integer>${value}</integer>` : `${pad}<real>${value}</real>`;
  if (typeof value === "string") return `${pad}<string>${escape(value)}</string>`;
  if (value && typeof value === "object") {
    const entries = Object.entries(value).map(([key, item]) => `${pad}\t<key>${escape(key)}</key>\n${node(item, indent + 1)}`);
    return `${pad}<dict>\n${entries.join("\n")}\n${pad}</dict>`;
  }
  throw new Error(`Unsupported plist value: ${value}`);
}

/** Serializes a JS object to an XML property list. `{ data: Buffer }` becomes `<data>`. */
export function plist(value) {
  return `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n${node(value, 0)}\n</plist>\n`;
}
