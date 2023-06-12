import os
import glob
import math
import numpy as np
from PIL import Image

if 'png' not in os.listdir('./'):
    os.mkdir('png')
else: 
    for f in glob.glob('./png/*'):
        os.remove(f)

raw = glob.glob('*.raw')
for r in raw:
    if os.path.getsize(r) == 49152:
        rawData = open(r, 'rb').read()
        img = Image.frombytes('RGB', (128,128), rawData)
        img.save('./png/' + r[:-4] + '.png')

txt = open('psnr.txt', 'w')
for i in sorted(os.listdir('./png')):
    result = np.array(Image.open('./png/' + i), dtype=np.float32)
    golden = np.array(Image.open('./golden/' + i), dtype=np.float32)

    b = 2
    diff = result[b:-b,b:-b,:]-golden[b:-b,b:-b,:]
    num = np.size(diff[:,:,1])
    MSE_R = np.sum(np.power(diff[:,:,2],2)) / num
    MSE_G = np.sum(np.power(diff[:,:,1],2)) / num
    MSE_B = np.sum(np.power(diff[:,:,0],2)) / num
    CMSE = (MSE_R + MSE_G + MSE_B) / 3
    CPSNR = 10*math.log(255*255/CMSE,10)

    txt.write(i+': '+str(round(CPSNR, 2))+'\n')
txt.close()
