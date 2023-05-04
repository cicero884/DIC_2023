import sys
from PIL import Image
import numpy as np
from fxpmath import Fxp
from scipy.signal import convolve2d
from skimage.measure import block_reduce

kernel = np.array([
    [-0.0625,0, -0.125,0, -0.0625],
    [0,      0,      0,0,       0],
    [-0.25,  0,      1,0,   -0.25],
    [0,      0,      0,0,       0],
    [-0.0625,0, -0.125,0, -0.0625]
]).astype(np.float32);

bias = -0.75;

def gray_64x64(img):
    small_img = img.resize((64,64),Image.BILINEAR);
    return np.asarray(small_img.convert('L'));

def layer0(img_array):
    img_pad = np.pad(img_array,((2,2),(2,2)),'edge');
    img_conv = convolve2d(img_pad,kernel,mode='valid')+bias;
    img_relu = np.maximum(0,img_conv);
    return img_relu;

def layer1(img_array):
    img_maxpool = block_reduce(img_array,(2,2),np.max);
    img_round = np.ceil(img_maxpool)
    return img_round;

def output(img_array,filename):
    print(img_array);
    img_fxp = Fxp(img_array,signed=True, n_word=13,n_frac=4);
    print(img_fxp);
    f = open(f"{filename}.dat","w");
    i=0;
    for column in img_fxp:
        for data in column:
            f.write(f"{data.bin()} //data {i}: {data}\n");
            i=i+1;
    f.close();

    img_file = Image.fromarray(img_array.astype(np.uint8));
    img_file.save(f"{filename}.png");

def convert(img):
    img_gray64x64 = gray_64x64(img);
    output(img_gray64x64,"img");
    
    img_L0 = layer0(img_gray64x64);
    output(img_L0,"layer0_golden");

    img_L1 = layer1(img_L0);
    output(img_L1,"layer1_golden");
    return;

if __name__ == "__main__":
    if len(sys.argv) == 2:
        img=Image.open(sys.argv[1]);
        convert(img);
        img.close();
    else:
        print("Usage:python ./maini.py image_name");
