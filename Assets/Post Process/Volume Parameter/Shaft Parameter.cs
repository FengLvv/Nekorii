using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable, VolumeComponentMenu( "Custom/VolumeLight" )]
public class ShaftParameter : VolumeComponent, IPostProcessComponent {
	[Header( "RT setting" )]
	public ClampedIntParameter DownSampleTimes = new ClampedIntParameter( 1, 0, 3, true );
	[Header( "March setting" )]
	//定义shader要用的参数
	public ClampedFloatParameter MarchSteps = new ClampedFloatParameter( 0, 0, 50, true );
	public FloatParameter MaxStepDistance = new FloatParameter( 500, true );
	public ClampedFloatParameter NearPlaneDistance = new ClampedFloatParameter( 2, 0, 10, true );
	public ClampedFloatParameter FarPointDistance = new ClampedFloatParameter( 0.25f, 0, 3, true );
	[Tooltip( "Control beer's law" )]
	public ClampedFloatParameter ExtinctionFactor = new ClampedFloatParameter( 1f, 0, 5, true );
	public ClampedFloatParameter Density = new ClampedFloatParameter( 0.012f, 0, 0.8f, true );
	public ColorParameter LightColor = new ColorParameter( Color.white, hdr:true, showAlpha:false, showEyeDropper:true );

	[Header( "Blur" )]
	public BoolParameter EnableBlur = new BoolParameter( true, true );
	public IntParameter BlurStepMultiple = new IntParameter( 15, true );
	public ClampedFloatParameter ColorSigma = new ClampedFloatParameter( 0.1f, 0.1f, 5f, true );
	public ClampedFloatParameter SpacialSigma = new ClampedFloatParameter( 1f, 0.5f, 5f, true );

	[Tooltip( "Control the scattering direction" )]
	public ClampedFloatParameter HG_g = new ClampedFloatParameter( 0.75f, 0, 0.999f, true );


	public bool IsActive() {
		return MarchSteps.value > 0;
	}

	public bool IsTileCompatible() {
		return false;
	}
}