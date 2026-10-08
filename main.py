import serial as serial
import numpy as np
import struct as struct
import matplotlib.pyplot as plt
import time

IMAGE_SIZE = 256
TOTAL_EXPECTED = int(IMAGE_SIZE * IMAGE_SIZE)

ser = serial.Serial('COM7', 115200)
ser.reset_input_buffer()

print("Pokreni slanje na FPGA ")

data_buffer = bytearray()
while len(data_buffer) < TOTAL_EXPECTED:
    chunk = ser.read(TOTAL_EXPECTED - len(data_buffer))
    if chunk:
        data_buffer.extend(chunk)
        print(f"Učitano: {len(data_buffer)} / {TOTAL_EXPECTED} bajtova", end='\r')
    else:
        if len(data_buffer) > 0: 
            time.sleep(0.01)
        if len(data_buffer) == 0: 
            continue


pixelVals = struct.unpack(f'<{TOTAL_EXPECTED}B', data_buffer)
fpgaIm = np.reshape(np.array(pixelVals), [IMAGE_SIZE, IMAGE_SIZE]).astype(np.uint8)
ser.close()


np.savetxt("matrica_piksela.txt", fpgaIm, fmt='%d')

swInput = plt.imread('cameraman.bmp')


def software_sobel(image):
    img = image.astype(np.float32)
    h, w = img.shape
    res = np.zeros((h-2, w-2), dtype=np.float32)
    gx_k = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])
    gy_k = np.array([[1, 2, 1], [0, 0, 0], [-1, -2, -1]])
    for y in range(1, h-1):
        for x in range(1, w-1):
            region = img[y-1:y+2, x-1:x+2]
            gx = np.sum(region * gx_k); gy = np.sum(region * gy_k)
            res[y-1, x-1] = np.sqrt(gx**2 + gy**2)
    return res

swIm = software_sobel(swInput)

fpga_trimmed = fpgaIm[1:255, 1:255]
def norm(img):
    if np.max(img) == 0: return img
    return ((img - np.min(img)) / (np.max(img) - np.min(img)) * 255).astype(np.uint8)

fpga_final = norm(fpga_trimmed)
sw_final = norm(swIm)

razlika = np.abs(sw_final.astype(np.int16) - fpga_final.astype(np.int16))


# Prikaz
plt.figure(figsize=(15, 5))
plt.subplot(1, 3, 1); plt.imshow(fpga_final, cmap='gray'); plt.title("FPGA Izlaz")
plt.subplot(1, 3, 2); plt.imshow(sw_final, cmap='gray'); plt.title("Software Model")
plt.subplot(1, 3, 3); plt.imshow(razlika, cmap='gray', vmin=0, vmax=255)
plt.show()
