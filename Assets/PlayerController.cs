using UnityEngine;

public class PlayerController : MonoBehaviour
{
    [SerializeField] private Material gameMat;

    public float speed = 0.001f;
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
        SmoothParameters();
        UpdateShader();
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
        gameMat.SetVector("_Pos", smoothPosition);
        gameMat.SetFloat("_Scale", smoothScale);
        gameMat.SetFloat("_Ang1", smoothAngle1);
        gameMat.SetFloat("_Ang2", smoothAngle2);
        gameMat.SetVector("_Color", smoothColor);
        gameMat.SetVector("_Shift", smoothShift);
        gameMat.SetVector("_Resolution", new Vector2(Screen.width, Screen.height));

        var camMat = Matrix4x4.TRS(Vector3.zero, smoothCamRotation, Vector3.one);
        gameMat.SetMatrix("_CamMat", camMat);
    }
}
