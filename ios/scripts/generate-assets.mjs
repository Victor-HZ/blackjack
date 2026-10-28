// Rasterize the original vector icon; Chromium is needed only for regenerating assets.
import { chromium } from '../../node_modules/playwright-core/index.mjs';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'BlackjackStudio/Resources/Assets.xcassets');
const svg = await readFile(path.join(root, 'Design/AppIcon.svg'), 'utf8');
const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || '/usr/bin/chromium', args: ['--no-sandbox'] });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.setContent(`<html><body style="margin:0;width:100vw;height:100vh;overflow:hidden">${svg.replace('<svg ', '<svg style="width:100%;height:100%;display:block" ')}</body></html>`);
  const entries = [];
  for (const [idiom, size, scales] of [['iphone',20,[2,3]],['iphone',29,[2,3]],['iphone',40,[2,3]],['iphone',60,[2,3]],['ipad',20,[1,2]],['ipad',29,[1,2]],['ipad',40,[1,2]],['ipad',76,[1,2]],['ipad',83.5,[2]],['ios-marketing',1024,[1]]]) {
    for (const scale of scales) {
      const pixels = size * scale;
      const filename = `icon-${pixels}.png`;
      await page.setViewportSize({width:pixels,height:pixels});
      await page.screenshot({path:path.join(output,'AppIcon.appiconset',filename),animations:'disabled',omitBackground:false});
      entries.push({idiom,size:`${size}x${size}`,scale:`${scale}x`,filename});
    }
  }
  await writeFile(path.join(output,'AppIcon.appiconset/Contents.json'),JSON.stringify({images:entries,info:{author:'xcode',version:1}},null,2)+'\n');
  await writeFile(path.join(output,'Contents.json'),JSON.stringify({info:{author:'xcode',version:1}},null,2)+'\n');
  for (const [name, light, dark] of [['AccentColor','#326348','#A7C9B0'],['LaunchBackground','#F2F2F7','#000000']]) {
    const color = hex => ({'color-space':'srgb',components:{alpha:'1.000',red:(parseInt(hex.slice(1,3),16)/255).toFixed(3),green:(parseInt(hex.slice(3,5),16)/255).toFixed(3),blue:(parseInt(hex.slice(5,7),16)/255).toFixed(3)}});
    await mkdir(path.join(output,name+'.colorset'),{recursive:true});
    await writeFile(path.join(output,name+'.colorset/Contents.json'),JSON.stringify({colors:[{idiom:'universal',color:color(light)},{idiom:'universal',appearances:[{appearance:'luminosity',value:'dark'}],color:color(dark)}],info:{author:'xcode',version:1}},null,2)+'\n');
  }
  console.log(`Generated ${entries.length} AppIcon entries and adaptive accent/launch colors.`);
} finally { await browser.close(); }
