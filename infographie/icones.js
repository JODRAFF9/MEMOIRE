// Rend les icones react-icons en PNG base64 pour insertion dans le PPTX.
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const sharp = require("sharp");

async function png(IconComponent, couleur, taille = 320) {
  const svg = renderToStaticMarkup(
    React.createElement(IconComponent, { color: couleur, size: taille })
  );
  const buf = await sharp(Buffer.from(svg)).resize(taille, taille).png().toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

module.exports = { png };
