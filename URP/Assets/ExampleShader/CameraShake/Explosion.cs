using UnityEngine;
using System.Collections;

public class Explosion : MonoBehaviour
{
    [SerializeField]
    ShakeableTransform target;

    [SerializeField]
    float delay = 1f;

    [SerializeField]
    float range = 45;

    [SerializeField]
    float maximumStress = 0.6f;

    private IEnumerator Start()
    {
        yield return new WaitForSeconds(delay);

        GetComponent<ParticleSystem>().Play();

        //根据离摄像机距离 调节压力系数
        float distance = Vector3.Distance(transform.position, target.transform.position);
        float distance01 = Mathf.Clamp01(distance / range);

        float stress = (1 - Mathf.Pow(distance01, 2)) * maximumStress;

        target.InduceStress(stress);
    }
}