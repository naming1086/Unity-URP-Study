using UnityEngine;

public class ShakeableTransform : MonoBehaviour
{
    [SerializeField]
    float frequency = 25;
    [SerializeField]
    Vector3 maximumTranslationShake = Vector3.one * 0.5f;
    [SerializeField]
    Vector3 maximumAngularShake = Vector3.one * 2;
    [SerializeField]
    float recoverySpeed = 1.5f;

    // Add as a new field and method.
    private float seed;

    // We set trauma to 1 to trigger an impact when the scene is run,
    // for debug purposes. This will later be changed to initialize trauma at 0.
    private float trauma = 1;

    private void Update()
    {
        transform.localPosition = new Vector3(
            maximumTranslationShake.x * (Mathf.PerlinNoise(seed, Time.time * frequency) * 2 - 1),
            maximumTranslationShake.y * (Mathf.PerlinNoise(seed + 1, Time.time * frequency) * 2 - 1),
            maximumTranslationShake.z * (Mathf.PerlinNoise(seed + 2, Time.time * frequency) * 2 - 1)
            ) * trauma;

        transform.localRotation = Quaternion.Euler(new Vector3(
            maximumAngularShake.x * (Mathf.PerlinNoise(seed + 3, Time.time * frequency) * 2 - 1),
            maximumAngularShake.y * (Mathf.PerlinNoise(seed + 4, Time.time * frequency) * 2 - 1),
            maximumAngularShake.z * (Mathf.PerlinNoise(seed + 5, Time.time * frequency) * 2 - 1)
            ) * trauma);
    }
}