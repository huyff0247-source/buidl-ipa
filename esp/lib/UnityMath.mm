#import "UnityMath.h"

#pragma mark - Function Unity

Vector3 WorldToScreen(Vector3 obj, float *matrix, float screenX, float screenY) {
    Vector3 screen;
    float w = matrix[3] * obj.x + matrix[7] * obj.y + matrix[11] * obj.z + matrix[15];
    // Diem sau lung camera (w<=0) -> khong hien (day ra ngoai man hinh)
    if (w < 0.01f) { screen.x = -99999.0f; screen.y = -99999.0f; screen.z = 0; return screen; }
    
    float x = (screenX / 2) + (matrix[0] * obj.x + matrix[4] * obj.y + matrix[8] * obj.z + matrix[12]) / w * (screenX / 2);
    float y = (screenY / 2) - (matrix[1] * obj.x + matrix[5] * obj.y + matrix[9] * obj.z + matrix[13]) / w * (screenY / 2);
    screen.x = x;
    screen.y = y;
    return screen;
}

Vector3 getPositionExt(uint64_t transObj2) {
    uint64_t transObj = ReadAddr<uint64_t>(transObj2 + 0x10);
    
    uint64_t matrix = ReadAddr<uint64_t>(transObj + 0x38);
    uint64_t index = ReadAddr<uint64_t>(transObj + 0x40);
    
    uint64_t matrix_list = ReadAddr<uint64_t>(matrix + 0x18);
    uint64_t matrix_indices = ReadAddr<uint64_t>(matrix + 0x20);
    
    Vector3 result = ReadAddr<Vector3>(matrix_list + sizeof(TMatrix) * index);
    int transformIndex = ReadAddr<int>(matrix_indices + sizeof(int) * index);
    
    while (transformIndex >= 0) {
        TMatrix tMatrix = ReadAddr<TMatrix>(matrix_list + sizeof(TMatrix) * transformIndex);
        
        float rotX = tMatrix.rotation.x;
        float rotY = tMatrix.rotation.y;
        float rotZ = tMatrix.rotation.z;
        float rotW = tMatrix.rotation.w;
        
        float scaleX = result.x * tMatrix.scale.x;
        float scaleY = result.y * tMatrix.scale.y;
        float scaleZ = result.z * tMatrix.scale.z;
        
        result.x = tMatrix.position.x + scaleX +
                    (scaleX * ((rotY * rotY * -2.0) - (rotZ * rotZ * 2.0))) +
                    (scaleY * ((rotW * rotZ * -2.0) - (rotY * rotX * -2.0))) +
                    (scaleZ * ((rotZ * rotX * 2.0) - (rotW * rotY * -2.0)));
        result.y = tMatrix.position.y + scaleY +
                    (scaleX * ((rotX * rotY * 2.0) - (rotW * rotZ * -2.0))) +
                    (scaleY * ((rotZ * rotZ * -2.0) - (rotX * rotX * 2.0))) +
                    (scaleZ * ((rotW * rotX * -2.0) - (rotZ * rotY * -2.0)));
        result.z = tMatrix.position.z + scaleZ +
                    (scaleX * ((rotW * rotY * -2.0) - (rotX * rotZ * -2.0))) +
                    (scaleY * ((rotY * rotZ * 2.0) - (rotW * rotX * -2.0))) +
                    (scaleZ * ((rotX * rotX * -2.0) - (rotY * rotY * 2.0)));
        
        transformIndex = ReadAddr<int>(matrix_indices + sizeof(int) * transformIndex);
    }
    
    return result;
}

// Lay quaternion xoay THE GIOI cua transform node (cung hierarchy nhu getPositionExt).
// Tich luy rotation tu node len root: worldRot = rootRot * ... * parentRot * nodeRot.
Quaternion getRotationExt(uint64_t transObj2) {
    uint64_t transObj = ReadAddr<uint64_t>(transObj2 + 0x10);

    uint64_t matrix = ReadAddr<uint64_t>(transObj + 0x38);
    uint64_t index = ReadAddr<uint64_t>(transObj + 0x40);

    uint64_t matrix_list = ReadAddr<uint64_t>(matrix + 0x18);
    uint64_t matrix_indices = ReadAddr<uint64_t>(matrix + 0x20);

    TMatrix nodeM = ReadAddr<TMatrix>(matrix_list + sizeof(TMatrix) * index);
    Quaternion result = nodeM.rotation;
    int transformIndex = ReadAddr<int>(matrix_indices + sizeof(int) * index);

    while (transformIndex >= 0) {
        TMatrix tMatrix = ReadAddr<TMatrix>(matrix_list + sizeof(TMatrix) * transformIndex);
        result = tMatrix.rotation * result;  // parent * child (Hamilton)
        transformIndex = ReadAddr<int>(matrix_indices + sizeof(int) * transformIndex);
    }
    return result;
}

// Dung ma tran MVP (View-Projection) column-major khop dung WorldToScreen hien tai:
//   clipX = m[0]x+m[4]y+m[8]z+m[12]  (= f/aspect * dot(right, p-eye))
//   clipY = m[1]x+m[5]y+m[9]z+m[13]  (= f       * dot(up,    p-eye))
//   clipW = m[3]x+m[7]y+m[11]z+m[15] (=          dot(fwd,   p-eye))
// eye = vi tri camera, camRot = xoay camera. Unity: forward=+Z, up=+Y, right=+X.
void BuildViewMatrix(Vector3 eye, Quaternion camRot, float fovVertDeg, float aspect, float *m) {
    Vector3 right = camRot * Vector3(1, 0, 0);
    Vector3 up    = camRot * Vector3(0, 1, 0);
    Vector3 fwd   = camRot * Vector3(0, 0, 1);

    float fovRad = fovVertDeg * (float)M_PI / 180.0f;
    float f = 1.0f / tanf(fovRad * 0.5f);
    if (aspect < 0.01f) aspect = 1.0f;
    float kx = f / aspect;
    float ky = f;

    float dR = Vector3::Dot(right, eye);
    float dU = Vector3::Dot(up, eye);
    float dF = Vector3::Dot(fwd, eye);

    // Row 0 -> clipX
    m[0] = kx * right.x;  m[4] = kx * right.y;  m[8]  = kx * right.z;  m[12] = -kx * dR;
    // Row 1 -> clipY
    m[1] = ky * up.x;     m[5] = ky * up.y;     m[9]  = ky * up.z;     m[13] = -ky * dU;
    // Row 2 -> clipZ (khong dung boi WorldToScreen)
    m[2] = 0;             m[6] = 0;             m[10] = 0;             m[14] = 0;
    // Row 3 -> clipW = do sau theo huong nhin
    m[3] = fwd.x;         m[7] = fwd.y;         m[11] = fwd.z;         m[15] = -dF;
}

NSString *GetNickName(uint64_t PawnObject) {
    uint64_t name = ReadAddr<uint64_t>(PawnObject + 0x430);
    
    UTF8 PlayerName[32] = "";
    UTF16 buf16[16] = {0};
    
    _read(name + 0x14, buf16, 28);
    Utf16_To_Utf8(buf16, PlayerName, 28, strictConversion);
    
    return [NSString stringWithUTF8String:(const char *)PlayerName];
}