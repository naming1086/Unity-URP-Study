using UnityEngine;

public class ShakeableTransform : MonoBehaviour
{
    [SerializeField]
    float frequency = 25;   //频率
    [SerializeField]
    Vector3 maximumTranslationShake = Vector3.one * 0.5f;   //最大位移震动
    [SerializeField]
    Vector3 maximumAngularShake = Vector3.one * 2;  //最大角度震动
    [SerializeField]
    float recoverySpeed = 1.5f; //复原速度
    [SerializeField]
    float traumaExponent = 2;       //创伤指数

    private float seed;     //随机种子
    
    private float trauma = 0;   //创伤系数

    private void Update()
    {
        float shake = Mathf.Pow(trauma, traumaExponent);

        transform.localPosition = new Vector3(
            maximumTranslationShake.x * (Mathf.PerlinNoise(seed, Time.time * frequency) * 2 - 1),
            maximumTranslationShake.y * (Mathf.PerlinNoise(seed + 1, Time.time * frequency) * 2 - 1),
            maximumTranslationShake.z * (Mathf.PerlinNoise(seed + 2, Time.time * frequency) * 2 - 1)
            ) * shake;

        transform.localRotation = Quaternion.Euler(new Vector3(
            maximumAngularShake.x * (Mathf.PerlinNoise(seed + 3, Time.time * frequency) * 2 - 1),
            maximumAngularShake.y * (Mathf.PerlinNoise(seed + 4, Time.time * frequency) * 2 - 1),
            maximumAngularShake.z * (Mathf.PerlinNoise(seed + 5, Time.time * frequency) * 2 - 1)
            ) * shake);

        trauma = Mathf.Clamp01(trauma - recoverySpeed * Time.deltaTime);
    }

    /// <summary>
    /// 引发压力 摄像机震动
    /// </summary>
    /// <param name="stress">压力系数，震动幅度正相关</param>
    public void InduceStress(float stress)
    {
        trauma = Mathf.Clamp01(trauma + stress);
    }
}