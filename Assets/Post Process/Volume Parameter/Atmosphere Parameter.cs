using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable, VolumeComponentMenu( "Custom/Atmosphere" )]
public class AtmosphereParameter : VolumeComponent, IPostProcessComponent {
	[Header( "RT setting" )]
	public ClampedIntParameter DownSampleTimes = new ClampedIntParameter( 1, 0, 3, true );

	[Header( "Blur" )]
	public BoolParameter EnableBlur = new BoolParameter( true, true );
	public IntParameter BlurStepMultiple = new IntParameter( 15, true );
	public ClampedFloatParameter ColorSigma = new ClampedFloatParameter( 0.1f, 0.1f, 5f, true );
	public ClampedFloatParameter SpacialSigma = new ClampedFloatParameter( 1f, 0.5f, 5f, true );

	[Header("Atmosphere")]
	public ColorParameter LightColor = new ColorParameter( Color.white, hdr:true, showAlpha:false, showEyeDropper:true );
	public ClampedFloatParameter MarchStepsAtmosphere = new ClampedFloatParameter( 15, 0, 50, true );
	public ClampedFloatParameter MarchStepsSun = new ClampedFloatParameter( 15, 0, 50, true );
	public FloatParameter PlanetRadius = new FloatParameter( 6371000.0f, true );
	public FloatParameter AtmosphereHeight  = new FloatParameter( 80000.0f, true );
	[Tooltip("Ray marching is calculated with really large unit, so scale the step length when near the ground to access the real length.")]
	public ClampedFloatParameter GroundStepScale = new ClampedFloatParameter( 12, 1, 20, true );

	[Tooltip( "Control the scattering direction" )]
	public ClampedFloatParameter HG_g = new ClampedFloatParameter( 0.75f, 0, 0.999f, true );
	public ClampedFloatParameter RayleighWeight = new ClampedFloatParameter( 1f, 0, 1f, true );
	public ClampedFloatParameter MieWeight = new ClampedFloatParameter( 1f, 0, 1f, true );

	public bool IsActive() {
		return MarchStepsAtmosphere.value > 0;
	}

	public bool IsTileCompatible() {
		return false;
	}
}