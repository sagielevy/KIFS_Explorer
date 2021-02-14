using UnityEngine;

public class PlayerController : MonoBehaviour
{
    [SerializeField] private Material gameMat;

    [Range(0.1f, 100)] public float lodIncreaseStartMultiplier = 1;

    public int minFractalIter = 16;
    public int maxFractalIter = 30;
    public float maxSpeed = 0.01f;
    public float smoothSpeed = 0.03f;
    public float mouseSpeed = 1;
    public float randomizeDelta = 0.1f;

    public Vector3 position = new Vector3(0, 0, 10);
    public Quaternion camRotation = Quaternion.identity;

    // Change to terraform the world.
    public float scale = 1.5f;
    public float angle1 = 2;
    public float angle2 = Mathf.PI;
    public Vector3 color = new Vector3(-0.42f, -0.38f, -0.19f);
    public Vector3 shift = new Vector3(-4.0f, -1.0f, -1.0f);

    private int shaderFractalIter = 20;
    private float speed = 0.01f;

    private Vector3 smoothPosition;
    private Quaternion smoothCamRotation;
    private float smoothScale;
    private float smoothAngle1;
    private float smoothAngle2;
    private Vector3 smoothColor;
    private Vector3 smoothShift;

    private void Start()
    {
        smoothPosition = position;
        smoothScale = scale;
        smoothAngle1 = angle1;
        smoothAngle2 = angle2;
        smoothColor = color;
        smoothShift = shift;
        smoothCamRotation = camRotation;

        UpdateShader();
    }

    private void Update()
    {
        HandleInput();
        UpdateSpeed();
        SmoothParameters();
        UpdateShader();
    }

    private void UpdateSpeed()
    {
        const float damp = 1.0f / 100000;
        float lod = 1.0f / (1000 * lodIncreaseStartMultiplier);
        var estimatedDistance = Mathf.Max(DE(position, minFractalIter), 0);

        
        shaderFractalIter = Mathf.RoundToInt(
            Mathf.Lerp(maxFractalIter, minFractalIter, Mathf.Clamp01(Mathf.Sqrt(estimatedDistance * lod))));

        //Debug.Log($"fract {shaderFractalIter} de { Mathf.Sqrt(estimatedDistance * lod) } " );

        speed = Mathf.Min(estimatedDistance * damp, maxSpeed);
    }

    //Hard-coded to match the fractal
    private float DE(Vector3 p, int iter)
    {
        //Vector4 p = new Vector4(pt.x, pt.y, pt.z, 1);

        for (int i = 0; i < iter; i++)
        {
            //absFold
            p = new Vector3(Mathf.Abs(p.x), Mathf.Abs(p.y), Mathf.Abs(p.z));

            //rotZ
            float rotz_c = Mathf.Cos(angle1);
            float rotz_s = Mathf.Sin(angle1);
            float rotz_x = rotz_c * p.x + rotz_s * p.y;
            float rotz_y = rotz_c * p.y - rotz_s * p.x;
            p.x = rotz_x;
            p.y = rotz_y;

            //mengerFold
            float mf = Mathf.Min(p.x - p.y, 0.0f);
            p.x -= mf; p.y += mf;
            mf = Mathf.Min(p.x - p.z, 0.0f);
            p.x -= mf;
            p.z += mf;
            mf = Mathf.Min(p.y - p.z, 0.0f);
            p.y -= mf;
            p.z += mf;

            //rotX
            float rotx_c = Mathf.Cos(angle2);
            float rotx_s = Mathf.Sin(angle2);
            float rotx_y = rotx_c * p.y + rotx_s * p.z;
            float rotx_z = rotx_c * p.z - rotx_s * p.y;
            p.y = rotx_y;
            p.z = rotx_z;

            //scaleTrans
            p *= scale;
            p += shift;
        }

        Vector3 a = new Vector3(Mathf.Abs(p.x), Mathf.Abs(p.y), Mathf.Abs(p.z)) -
                new Vector3(6.0f, 6.0f, 6.0f);

        return Mathf.Min(Mathf.Max(Mathf.Max(a.x, a.y), a.z), 0.0f) +
                new Vector3(Mathf.Max(a.x, 0), Mathf.Max(a.y, 0), Mathf.Max(a.z, 0)).magnitude;
    }

    private void HandleInput()
    {
        var mouseX = Input.GetAxis("Mouse X") * mouseSpeed;
        var mouseY = Input.GetAxis("Mouse Y") * mouseSpeed;
        camRotation = Quaternion.Euler(camRotation.eulerAngles.x + mouseY, camRotation.eulerAngles.y - mouseX, 0);

        var forward = camRotation * Vector3.forward;
        var right = camRotation * Vector3.right;

        if (Input.GetKey(KeyCode.A))
        {
            position -= right * speed;
        }
        else if (Input.GetKey(KeyCode.D))
        {
            position += right * speed;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            position += forward * speed;
        }
        else if (Input.GetKey(KeyCode.W))
        {
            position -= forward * speed;
        }
        else if (Input.GetKeyDown(KeyCode.R))
        {
            RandomizeWorld();
        }
    }

    private void RandomizeWorld()
    {
        scale = RandomForDelta(scale);
        angle1 = RandomForDelta(angle1);
        angle2 = RandomForDelta(angle2);
        color = RandomForDelta(color);
        shift = RandomForDelta(shift);
    }

    // Shifts val by a maximum of +-(val * randomizeDelta)
    private float RandomForDelta(float val)
    {
        return val + Random.Range(-randomizeDelta * val, randomizeDelta * val);
    }

    private Vector3 RandomForDelta(Vector3 val)
    {
        return new Vector3(RandomForDelta(val.x), RandomForDelta(val.y), RandomForDelta(val.z));
    }

    private void SmoothParameters()
    {
        smoothPosition = Vector3.Lerp(smoothPosition, position, smoothSpeed);
        smoothCamRotation = Quaternion.Lerp(smoothCamRotation, camRotation, smoothSpeed);
        smoothScale = Mathf.Lerp(smoothScale, scale, smoothSpeed);
        smoothAngle1 = Mathf.Lerp(smoothAngle1, angle1, smoothSpeed);
        smoothAngle2 = Mathf.Lerp(smoothAngle2, angle2, smoothSpeed);
        smoothColor = Vector3.Lerp(smoothColor, color, smoothSpeed);
        smoothShift = Vector3.Lerp(smoothShift, shift, smoothSpeed);
    }

    private void UpdateShader()
    {
        gameMat.SetFloat("_Scale", smoothScale);
        gameMat.SetFloat("_Ang1", smoothAngle1);
        gameMat.SetFloat("_Ang2", smoothAngle2);
        gameMat.SetVector("_Color", smoothColor);
        gameMat.SetVector("_Shift", smoothShift);
        gameMat.SetVector("_Resolution", new Vector2(Screen.width, Screen.height));
        gameMat.SetInt("_FractalIter", shaderFractalIter);

        var camMat = Matrix4x4.TRS(smoothPosition, smoothCamRotation, Vector3.one);
        gameMat.SetMatrix("_CamMat", camMat);
    }
}
