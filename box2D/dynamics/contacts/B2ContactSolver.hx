﻿/*
* Copyright (c) 2006-2007 Erin Catto http://www.gphysics.com
*
* This software is provided 'as-is', without any express or implied
* warranty.  In no event will the authors be held liable for any damages
* arising from the use of this software.
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 1. The origin of this software must not be misrepresented; you must not
* claim that you wrote the original software. If you use this software
* in a product, an acknowledgment in the product documentation would be
* appreciated but is not required.
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
* 3. This notice may not be removed or altered from any source distribution.
*/

package box2D.dynamics.contacts;


import box2D.collision.B2Manifold;
import box2D.collision.B2ManifoldPoint;
import box2D.collision.B2WorldManifold;
import box2D.collision.shapes.B2Shape;
import box2D.common.B2Settings;
import box2D.common.math.B2Mat22;
import box2D.common.math.B2Math;
import box2D.common.math.B2Vec2;
import box2D.dynamics.B2Body;
import box2D.dynamics.B2Fixture;
import box2D.dynamics.B2TimeStep;


/**
* @private
*/
class B2ContactSolver
{
	private static var staticFix = B2Settings.b2_maxManifoldPoints;
	
	public function new()
	{
		m_step = new B2TimeStep();
		m_constraints = new Array <B2ContactConstraint> ();
	}
	
	private static var s_worldManifold:B2WorldManifold = new B2WorldManifold();
	public function initialize(step:B2TimeStep, contacts:Array <B2Contact>, contactCount:Int, allocator:Dynamic):Void
	{
		var contact:B2Contact;
		
		m_step.set(step);
		
		m_allocator = allocator;
		
		var i:Int;
		var tVec:B2Vec2;
		var tMat:B2Mat22;
		
		m_constraintCount = contactCount;

		// fill vector to hold enough constraints
		while (m_constraints.length < m_constraintCount)
		{
			m_constraints[m_constraints.length] = new B2ContactConstraint();
		}
		
		for (i in 0...contactCount)
		{
			contact = contacts[i];
			var fixtureA:B2Fixture = contact.m_fixtureA;
			var fixtureB:B2Fixture = contact.m_fixtureB;
			var shapeA:B2Shape = fixtureA.m_shape;
			var shapeB:B2Shape = fixtureB.m_shape;
			var radiusA:Float = shapeA.m_radius;
			var radiusB:Float = shapeB.m_radius;
			var bodyA:B2Body = fixtureA.m_body;
			var bodyB:B2Body = fixtureB.m_body;
			var manifold:B2Manifold = contact.getManifold();
			
			var friction:Float = B2Settings.b2MixFriction(fixtureA.getFriction(), fixtureB.getFriction());
			var restitution:Float = B2Settings.b2MixRestitution(fixtureA.getRestitution(), fixtureB.getRestitution());
			var restitutionThreshold:Float = B2Settings.b2MixRestitutionThreshold(fixtureA.getRestitutionThreshold(), fixtureB.getRestitutionThreshold());
			
			//var vA:B2Vec2 = bodyA.m_linearVelocity.Copy();
			var vAX:Float = bodyA.m_linearVelocity.x;
			var vAY:Float = bodyA.m_linearVelocity.y;
			//var vB:B2Vec2 = bodyB.m_linearVelocity.Copy();
			var vBX:Float = bodyB.m_linearVelocity.x;
			var vBY:Float = bodyB.m_linearVelocity.y;
			var wA:Float = bodyA.m_angularVelocity;
			var wB:Float = bodyB.m_angularVelocity;
			
			B2Settings.b2Assert(manifold.m_pointCount > 0);
			
			s_worldManifold.initialize(manifold, bodyA.m_xf, radiusA, bodyB.m_xf, radiusB);
			
			var normalX:Float = s_worldManifold.m_normal.x;
			var normalY:Float = s_worldManifold.m_normal.y;
			
			var cc:B2ContactConstraint = m_constraints[ i ];
			cc.bodyA = bodyA; //p
			cc.bodyB = bodyB; //p
			cc.manifold = manifold; //p
			//c.normal = normal;
			cc.normal.x = normalX;
			cc.normal.y = normalY;
			cc.pointCount = manifold.m_pointCount;
			cc.friction = friction;
			cc.restitution = restitution;
			cc.restitutionThreshold = restitutionThreshold;
			
			cc.localPlaneNormal.x = manifold.m_localPlaneNormal.x;
			cc.localPlaneNormal.y = manifold.m_localPlaneNormal.y;
			cc.localPoint.x = manifold.m_localPoint.x;
			cc.localPoint.y = manifold.m_localPoint.y;
			cc.radius = radiusA + radiusB;
			cc.type = manifold.m_type;
			
			for (k in 0...cc.pointCount)
			{
				var cp:B2ManifoldPoint = manifold.m_points[ k ];
				var ccp:B2ContactConstraintPoint = cc.points[ k ];
				
				ccp.normalImpulse = cp.m_normalImpulse;
				ccp.tangentImpulse = cp.m_tangentImpulse;
				
				ccp.localPoint.setV(cp.m_localPoint);
				
				var rAX:Float = ccp.rA.x = s_worldManifold.m_points[k].x - bodyA.m_sweep.c.x;
				var rAY:Float = ccp.rA.y = s_worldManifold.m_points[k].y - bodyA.m_sweep.c.y;
				var rBX:Float = ccp.rB.x = s_worldManifold.m_points[k].x - bodyB.m_sweep.c.x;
				var rBY:Float = ccp.rB.y = s_worldManifold.m_points[k].y - bodyB.m_sweep.c.y;
				
				var rnA:Float = rAX * normalY - rAY * normalX;//b2Math.b2Cross(r1, normal);
				var rnB:Float = rBX * normalY - rBY * normalX;//b2Math.b2Cross(r2, normal);
				
				rnA *= rnA;
				rnB *= rnB;
				
				var kNormal:Float = bodyA.m_invMass + bodyB.m_invMass + bodyA.m_invI * rnA + bodyB.m_invI * rnB;
				//b2Settings.b2Assert(kNormal > Number.MIN_VALUE);
				ccp.normalMass = 1.0 / kNormal;
				
				var kEqualized:Float = bodyA.m_mass * bodyA.m_invMass + bodyB.m_mass * bodyB.m_invMass;
				kEqualized += bodyA.m_mass * bodyA.m_invI * rnA + bodyB.m_mass * bodyB.m_invI * rnB;
				//b2Assert(kEqualized > Number.MIN_VALUE);
				ccp.equalizedMass = 1.0 / kEqualized;
				
				//var tangent:B2Vec2 = b2Math.b2CrossVF(normal, 1.0);
				var tangentX:Float = normalY;
				var tangentY:Float = -normalX;
				
				//var rtA:Float = b2Math.b2Cross(rA, tangent);
				var rtA:Float = rAX*tangentY - rAY*tangentX;
				//var rtB:Float = b2Math.b2Cross(rB, tangent);
				var rtB:Float = rBX*tangentY - rBY*tangentX;
				
				rtA *= rtA;
				rtB *= rtB;
				
				var kTangent:Float = bodyA.m_invMass + bodyB.m_invMass + bodyA.m_invI * rtA + bodyB.m_invI * rtB;
				//b2Settings.b2Assert(kTangent > Number.MIN_VALUE);
				ccp.tangentMass = 1.0 /  kTangent;
				
				// Setup a velocity bias for restitution.
				ccp.velocityBias = 0.0;
				//b2Dot(c.normal, vB + b2Cross(wB, rB) - vA - b2Cross(wA, rA));
				var tX:Float = vBX + (-wB*rBY) - vAX - (-wA*rAY);
				var tY:Float = vBY + (wB*rBX) - vAY - (wA*rAX);
				//var vRel:Float = b2Dot(cc.normal, t);
				var vRel:Float = cc.normal.x*tX + cc.normal.y*tY;
				if (vRel < -cc.restitutionThreshold)
				{
					ccp.velocityBias += -cc.restitution * vRel;
				}
			}
			
			// If we have two points, then prepare the block solver.
			if (cc.pointCount == 2)
			{
				var ccp1:B2ContactConstraintPoint = cc.points[0];
				var ccp2:B2ContactConstraintPoint = cc.points[1];
				
				var invMassA:Float = bodyA.m_invMass;
				var invIA:Float = bodyA.m_invI;
				var invMassB:Float = bodyB.m_invMass;
				var invIB:Float = bodyB.m_invI;
				
				//var rn1A:Float = b2Cross(ccp1.rA, normal);
				//var rn1B:Float = b2Cross(ccp1.rB, normal);
				//var rn2A:Float = b2Cross(ccp2.rA, normal);
				//var rn2B:Float = b2Cross(ccp2.rB, normal);
				var rn1A:Float = ccp1.rA.x * normalY - ccp1.rA.y * normalX;
				var rn1B:Float = ccp1.rB.x * normalY - ccp1.rB.y * normalX;
				var rn2A:Float = ccp2.rA.x * normalY - ccp2.rA.y * normalX;
				var rn2B:Float = ccp2.rB.x * normalY - ccp2.rB.y * normalX;
				
				var k11:Float = invMassA + invMassB + invIA * rn1A * rn1A + invIB * rn1B * rn1B;
				var k22:Float = invMassA + invMassB + invIA * rn2A * rn2A + invIB * rn2B * rn2B;
				var k12:Float = invMassA + invMassB + invIA * rn1A * rn2A + invIB * rn1B * rn2B;
				
				// Ensure a reasonable condition number.
				var k_maxConditionNumber:Float = 100.0;
				if ( k11 * k11 < k_maxConditionNumber * (k11 * k22 - k12 * k12))
				{
					// K is safe to invert.
					cc.K.col1.set(k11, k12);
					cc.K.col2.set(k12, k22);
					cc.K.getInverse(cc.normalMass);
				}
				else
				{
					// The constraints are redundant, just use one.
					// TODO_ERIN use deepest?
					cc.pointCount = 1;
				}
			}
		}
		
		//b2Settings.b2Assert(count == m_constraintCount);
	}
	//~b2ContactSolver();

	public function initVelocityConstraints(step: B2TimeStep) : Void{
		var tVec:B2Vec2;
		var tVec2:B2Vec2;
		var tMat:B2Mat22;
		
		// Warm start.
		for (i in 0...m_constraintCount)
		{
			var c:B2ContactConstraint = m_constraints[ i ];
			
			var bodyA:B2Body = c.bodyA;
			var bodyB:B2Body = c.bodyB;
			var invMassA:Float = bodyA.m_invMass;
			var invIA:Float = bodyA.m_invI;
			var invMassB:Float = bodyB.m_invMass;
			var invIB:Float = bodyB.m_invI;
			//var normal:B2Vec2 = new B2Vec2(c.normal.x, c.normal.y);
			var normalX:Float = c.normal.x;
			var normalY:Float = c.normal.y;
			//var tangent:B2Vec2 = b2Math.b2CrossVF(normal, 1.0);
			var tangentX:Float = normalY;
			var tangentY:Float = -normalX;
			
			var tX:Float;
			
			var j:Int;
			var tCount:Int;
			if (step.warmStarting)
			{
				tCount = c.pointCount;
				for (j in 0...tCount)
				{
					var ccp:B2ContactConstraintPoint = c.points[ j ];
					ccp.normalImpulse *= step.dtRatio;
					ccp.tangentImpulse *= step.dtRatio;
					//b2Vec2 P = ccp->normalImpulse * normal + ccp->tangentImpulse * tangent;
					var PX:Float = ccp.normalImpulse * normalX + ccp.tangentImpulse * tangentX;
					var PY:Float = ccp.normalImpulse * normalY + ccp.tangentImpulse * tangentY;
					
					//bodyA.m_angularVelocity -= invIA * b2Math.b2CrossVV(rA, P);
					bodyA.m_angularVelocity -= invIA * (ccp.rA.x * PY - ccp.rA.y * PX);
					//bodyA.m_linearVelocity.Subtract( b2Math.MulFV(invMassA, P) );
					bodyA.m_linearVelocity.x -= invMassA * PX;
					bodyA.m_linearVelocity.y -= invMassA * PY;
					//bodyB.m_angularVelocity += invIB * b2Math.b2CrossVV(rB, P);
					bodyB.m_angularVelocity += invIB * (ccp.rB.x * PY - ccp.rB.y * PX);
					//bodyB.m_linearVelocity.Add( b2Math.MulFV(invMassB, P) );
					bodyB.m_linearVelocity.x += invMassB * PX;
					bodyB.m_linearVelocity.y += invMassB * PY;
				}
			}
			else
			{
				tCount = c.pointCount;
				for (j in 0...tCount)
				{
					var ccp2:B2ContactConstraintPoint = c.points[ j ];
					ccp2.normalImpulse = 0.0;
					ccp2.tangentImpulse = 0.0;
				}
			}
		}
	}
	public function solveVelocityConstraints() : Void{
		var j:Int;
		var ccp:B2ContactConstraintPoint;
		var rAX:Float;
		var rAY:Float;
		var rBX:Float;
		var rBY:Float;
		var dvX:Float;
		var dvY:Float;
		var vn:Float;
		var vt:Float;
		var lambda:Float;
		var maxFriction:Float;
		var newImpulse:Float;
		var PX:Float;
		var PY:Float;
		var dX:Float;
		var dY:Float;
		var P1X:Float;
		var P1Y:Float;
		var P2X:Float;
		var P2Y:Float;
		
		var tMat:B2Mat22;
		var tVec:B2Vec2;
		
		for (i in 0...m_constraintCount)
		{
			var c:B2ContactConstraint = m_constraints[ i ];
			var bodyA:B2Body = c.bodyA;
			var bodyB:B2Body = c.bodyB;
			var wA:Float = bodyA.m_angularVelocity;
			var wB:Float = bodyB.m_angularVelocity;
			var vA:B2Vec2 = bodyA.m_linearVelocity;
			var vB:B2Vec2 = bodyB.m_linearVelocity;
			
			var invMassA:Float = bodyA.m_invMass;
			var invIA:Float = bodyA.m_invI;
			var invMassB:Float = bodyB.m_invMass;
			var invIB:Float = bodyB.m_invI;
			//var normal:B2Vec2 = new B2Vec2(c.normal.x, c.normal.y);
			var normalX:Float = c.normal.x;
			var normalY:Float = c.normal.y;
			//var tangent:B2Vec2 = b2Math.b2CrossVF(normal, 1.0);
			var tangentX:Float = normalY;
			var tangentY:Float = -normalX;
			var friction:Float = c.friction;
			
			var tX:Float;
			
			//b2Settings.b2Assert(c.pointCount == 1 || c.pointCount == 2);
			// Solve the tangent constraints
			for (j in 0...c.pointCount)
			{
				ccp = c.points[j];
				
				// Relative velocity at contact
				//b2Vec2 dv = vB + b2Cross(wB, ccp->rB) - vA - b2Cross(wA, ccp->rA);
				dvX = vB.x - wB * ccp.rB.y - vA.x + wA * ccp.rA.y;
				dvY = vB.y + wB * ccp.rB.x - vA.y - wA * ccp.rA.x;
				
				// Compute tangent force
				vt = dvX * tangentX + dvY * tangentY;
				lambda = ccp.tangentMass * -vt;
				
				// b2Clamp the accumulated force
				maxFriction = friction * ccp.normalImpulse;
				newImpulse = B2Math.clamp(ccp.tangentImpulse + lambda, -maxFriction, maxFriction);
				lambda = newImpulse-ccp.tangentImpulse;
				
				// Apply contact impulse
				PX = lambda * tangentX;
				PY = lambda * tangentY;
				
				vA.x -= invMassA * PX;
				vA.y -= invMassA * PY;
				wA -= invIA * (ccp.rA.x * PY - ccp.rA.y * PX);
				
				vB.x += invMassB * PX;
				vB.y += invMassB * PY;
				wB += invIB * (ccp.rB.x * PY - ccp.rB.y * PX);
				
				ccp.tangentImpulse = newImpulse;
			}
			
			// Solve the normal constraints
			var tCount:Int = c.pointCount;
			if (c.pointCount == 1)
			{
				ccp = c.points[ 0 ];
				
				// Relative velocity at contact
				//b2Vec2 dv = vB + b2Cross(wB, ccp->rB) - vA - b2Cross(wA, ccp->rA);
				dvX = vB.x + (-wB * ccp.rB.y) - vA.x - (-wA * ccp.rA.y);
				dvY = vB.y + (wB * ccp.rB.x) - vA.y - (wA * ccp.rA.x);
				
				// Compute normal impulse
				//var vn:Float = b2Math.b2Dot(dv, normal);
				vn = dvX * normalX + dvY * normalY;
				lambda = -ccp.normalMass * (vn - ccp.velocityBias);
				
				// b2Clamp the accumulated impulse
				//newImpulse = b2Math.b2Max(ccp.normalImpulse + lambda, 0.0);
				newImpulse = ccp.normalImpulse + lambda;
				newImpulse = newImpulse > 0 ? newImpulse : 0.0;
				lambda = newImpulse - ccp.normalImpulse;
				
				// Apply contact impulse
				//b2Vec2 P = lambda * normal;
				PX = lambda * normalX;
				PY = lambda * normalY;
				
				//vA.Subtract( b2Math.MulFV( invMassA, P ) );
				vA.x -= invMassA * PX;
				vA.y -= invMassA * PY;
				wA -= invIA * (ccp.rA.x * PY - ccp.rA.y * PX);//invIA * b2Math.b2CrossVV(ccp.rA, P);
				
				//vB.Add( b2Math.MulFV( invMass2, P ) );
				vB.x += invMassB * PX;
				vB.y += invMassB * PY;
				wB += invIB * (ccp.rB.x * PY - ccp.rB.y * PX);//invIB * b2Math.b2CrossVV(ccp.rB, P);
				
				ccp.normalImpulse = newImpulse;
			}
			else
			{
				// Block solver developed in collaboration with Dirk Gregorius (back in 01/07 on Box2D_Lite).
				// Build the mini LCP for this contact patch
				//
				// vn = A * x + b, vn >= 0, , vn >= 0, x >= 0 and vn_i * x_i = 0 with i = 1..2
				//
				// A = J * W * JT and J = ( -n, -r1 x n, n, r2 x n )
				// b = vn_0 - velocityBias
				//
				// The system is solved using the "Total enumeration method" (s. Murty). The complementary constraint vn_i * x_i
				// implies that we must have in any solution either vn_i = 0 or x_i = 0. So for the 2D contact problem the cases
				// vn1 = 0 and vn2 = 0, x1 = 0 and x2 = 0, x1 = 0 and vn2 = 0, x2 = 0 and vn1 = 0 need to be tested. The first valid
				// solution that satisfies the problem is chosen.
				//
				// In order to account of the accumulated impulse 'a' (because of the iterative nature of the solver which only requires
				// that the accumulated impulse is clamped and not the incremental impulse) we change the impulse variable (x_i).
				//
				// Substitute:
				//
				// x = x' - a
				//
				// Plug into above equation:
				//
				// vn = A * x + b
				//    = A * (x' - a) + b
				//    = A * x' + b - A * a
				//    = A * x' + b'
				// b' = b - A * a;
				
				var cp1:B2ContactConstraintPoint = c.points[ 0 ];
				var cp2:B2ContactConstraintPoint = c.points[ 1 ];
				
				var aX:Float = cp1.normalImpulse;
				var aY:Float = cp2.normalImpulse;
				//b2Settings.b2Assert( aX >= 0.0f && aY >= 0.0f );
				
				// Relative velocity at contact
				//var dv1:B2Vec2 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA);
				var dv1X:Float = vB.x - wB * cp1.rB.y - vA.x + wA * cp1.rA.y;
				var dv1Y:Float = vB.y + wB * cp1.rB.x - vA.y - wA * cp1.rA.x;
				//var dv2:B2Vec2 = vB + b2Cross(wB, cpB.r2) - vA - b2Cross(wA, cp2.rA);
				var dv2X:Float = vB.x - wB * cp2.rB.y - vA.x + wA * cp2.rA.y;
				var dv2Y:Float = vB.y + wB * cp2.rB.x - vA.y - wA * cp2.rA.x;
				
				// Compute normal velocity
				//var vn1:Float = b2Dot(dv1, normal);
				var vn1:Float = dv1X * normalX + dv1Y * normalY;
				//var vn2:Float = b2Dot(dv2, normal);
				var vn2:Float = dv2X * normalX + dv2Y * normalY;
				
				var bX:Float = vn1 - cp1.velocityBias;
				var bY:Float = vn2 - cp2.velocityBias;
				
				//b -= b2Mul(c.K,a);
				tMat = c.K;
				bX -= tMat.col1.x * aX + tMat.col2.x * aY;
				bY -= tMat.col1.y * aX + tMat.col2.y * aY;
				
				var k_errorTol:Float  = 0.001;
				for (i in 0...1)
				{
					//
					// Case 1: vn = 0
					//
					// 0 = A * x' + b'
					//
					// Solve for x':
					//
					// x' = -inv(A) * b'
					//
					
					//var x:B2Vec2 = - b2Mul(c->normalMass, b);
					tMat = c.normalMass;
					var xX:Float = - (tMat.col1.x * bX + tMat.col2.x * bY);
					var xY:Float = - (tMat.col1.y * bX + tMat.col2.y * bY);
					
					if (xX >= 0.0 && xY >= 0.0) {
						// Resubstitute for the incremental impulse
						//d = x - a;
						dX = xX - aX;
						dY = xY - aY;
						
						//Aply incremental impulse
						//P1 = d.x * normal;
						P1X = dX * normalX;
						P1Y = dX * normalY;
						//P2 = d.y * normal;
						P2X = dY * normalX;
						P2Y = dY * normalY;
						
						//vA -= invMass1 * (P1 + P2)
						vA.x -= invMassA * (P1X + P2X);
						vA.y -= invMassA * (P1Y + P2Y);
						//wA -= invIA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2));
						wA -= invIA * ( cp1.rA.x * P1Y - cp1.rA.y * P1X + cp2.rA.x * P2Y - cp2.rA.y * P2X);
						
						//vB += invMassB * (P1 + P2)
						vB.x += invMassB * (P1X + P2X);
						vB.y += invMassB * (P1Y + P2Y);
						//wB += invIB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2));
						wB   += invIB * ( cp1.rB.x * P1Y - cp1.rB.y * P1X + cp2.rB.x * P2Y - cp2.rB.y * P2X);
						
						// Accumulate
						cp1.normalImpulse = xX;
						cp2.normalImpulse = xY;
						
	//#if B2_DEBUG_SOLVER == 1
	//					// Post conditions
	//					//dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA);
	//					dv1X = vB.x - wB * cp1.rB.y - vA.x + wA * cp1.rA.y;
	//					dv1Y = vB.y + wB * cp1.rB.x - vA.y - wA * cp1.rA.x;
	//					//dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA);
	//					dv1X = vB.x - wB * cp2.rB.y - vA.x + wA * cp2.rA.y;
	//					dv1Y = vB.y + wB * cp2.rB.x - vA.y - wA * cp2.rA.x;
	//					// Compute normal velocity
	//					//vn1 = b2Dot(dv1, normal);
	//					vn1 = dv1X * normalX + dv1Y * normalY;
	//					//vn2 = b2Dot(dv2, normal);
	//					vn2 = dv2X * normalX + dv2Y * normalY;
	//
	//					//b2Settings.b2Assert(b2Abs(vn1 - cp1.velocityBias) < k_errorTol);
	//					//b2Settings.b2Assert(b2Abs(vn2 - cp2.velocityBias) < k_errorTol);
	//#endif
						break;
					}
					
					//
					// Case 2: vn1 = 0  and x2 = 0
					//
					//   0 = a11 * x1' + a12 * 0 + b1'
					// vn2 = a21 * x1' + a22 * 0 + b2'
					//
					
					xX = - cp1.normalMass * bX;
					xY = 0.0;
					vn1 = 0.0;
					vn2 = c.K.col1.y * xX + bY;
					
					if (xX >= 0.0 && vn2 >= 0.0)
					{
						// Resubstitute for the incremental impulse
						//d = x - a;
						dX = xX - aX;
						dY = xY - aY;
						
						//Aply incremental impulse
						//P1 = d.x * normal;
						P1X = dX * normalX;
						P1Y = dX * normalY;
						//P2 = d.y * normal;
						P2X = dY * normalX;
						P2Y = dY * normalY;
						
						//vA -= invMassA * (P1 + P2)
						vA.x -= invMassA * (P1X + P2X);
						vA.y -= invMassA * (P1Y + P2Y);
						//wA -= invIA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2));
						wA -= invIA * ( cp1.rA.x * P1Y - cp1.rA.y * P1X + cp2.rA.x * P2Y - cp2.rA.y * P2X);
						
						//vB += invMassB * (P1 + P2)
						vB.x += invMassB * (P1X + P2X);
						vB.y += invMassB * (P1Y + P2Y);
						//wB += invIB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2));
						wB   += invIB * ( cp1.rB.x * P1Y - cp1.rB.y * P1X + cp2.rB.x * P2Y - cp2.rB.y * P2X);
						
						// Accumulate
						cp1.normalImpulse = xX;
						cp2.normalImpulse = xY;
						
	//#if B2_DEBUG_SOLVER == 1
	//					// Post conditions
	//					//dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA);
	//					dv1X = vB.x - wB * cp1.rB.y - vA.x + wA * cp1.rA.y;
	//					dv1Y = vB.y + wB * cp1.rB.x - vA.y - wA * cp1.rA.x;
	//					//dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA);
	//					dv1X = vB.x - wB * cp2.rB.y - vA.x + wA * cp2.rA.y;
	//					dv1Y = vB.y + wB * cp2.rB.x - vA.y - wA * cp2.rA.x;
	//					// Compute normal velocity
	//					//vn1 = b2Dot(dv1, normal);
	//					vn1 = dv1X * normalX + dv1Y * normalY;
	//					//vn2 = b2Dot(dv2, normal);
	//					vn2 = dv2X * normalX + dv2Y * normalY;
	//
	//					//b2Settings.b2Assert(b2Abs(vn1 - cp1.velocityBias) < k_errorTol);
	//					//b2Settings.b2Assert(b2Abs(vn2 - cp2.velocityBias) < k_errorTol);
	//#endif
						break;
					}
					
					//
					// Case 3: wB = 0 and x1 = 0
					//
					// vn1 = a11 * 0 + a12 * x2' + b1'
					//   0 = a21 * 0 + a22 * x2' + b2'
					//
					
					xX = 0.0;
					xY = -cp2.normalMass * bY;
					vn1 = c.K.col2.x * xY + bX;
					vn2 = 0.0;
					if (xY >= 0.0 && vn1 >= 0.0)
					{
						// Resubstitute for the incremental impulse
						//d = x - a;
						dX = xX - aX;
						dY = xY - aY;
						
						//Aply incremental impulse
						//P1 = d.x * normal;
						P1X = dX * normalX;
						P1Y = dX * normalY;
						//P2 = d.y * normal;
						P2X = dY * normalX;
						P2Y = dY * normalY;
						
						//vA -= invMassA * (P1 + P2)
						vA.x -= invMassA * (P1X + P2X);
						vA.y -= invMassA * (P1Y + P2Y);
						//wA -= invIA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2));
						wA -= invIA * ( cp1.rA.x * P1Y - cp1.rA.y * P1X + cp2.rA.x * P2Y - cp2.rA.y * P2X);
						
						//vB += invMassB * (P1 + P2)
						vB.x += invMassB * (P1X + P2X);
						vB.y += invMassB * (P1Y + P2Y);
						//wB += invIB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2));
						wB   += invIB * ( cp1.rB.x * P1Y - cp1.rB.y * P1X + cp2.rB.x * P2Y - cp2.rB.y * P2X);
						
						// Accumulate
						cp1.normalImpulse = xX;
						cp2.normalImpulse = xY;
						
	//#if B2_DEBUG_SOLVER == 1
	//					// Post conditions
	//					//dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA);
	//					dv1X = vB.x - wB * cp1.rB.y - vA.x + wA * cp1.rA.y;
	//					dv1Y = vB.y + wB * cp1.rB.x - vA.y - wA * cp1.rA.x;
	//					//dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA);
	//					dv1X = vB.x - wB * cp2.rB.y - vA.x + wA * cp2.rA.y;
	//					dv1Y = vB.y + wB * cp2.rB.x - vA.y - wA * cp2.rA.x;
	//					// Compute normal velocity
	//					//vn1 = b2Dot(dv1, normal);
	//					vn1 = dv1X * normalX + dv1Y * normalY;
	//					//vn2 = b2Dot(dv2, normal);
	//					vn2 = dv2X * normalX + dv2Y * normalY;
	//
	//					//b2Settings.b2Assert(b2Abs(vn1 - cp1.velocityBias) < k_errorTol);
	//					//b2Settings.b2Assert(b2Abs(vn2 - cp2.velocityBias) < k_errorTol);
	//#endif
						break;
					}
					
					//
					// Case 4: x1 = 0 and x2 = 0
					//
					// vn1 = b1
					// vn2 = b2
					
					xX = 0.0;
					xY = 0.0;
					vn1 = bX;
					vn2 = bY;
					
					if (vn1 >= 0.0 && vn2 >= 0.0 ) {
						// Resubstitute for the incremental impulse
						//d = x - a;
						dX = xX - aX;
						dY = xY - aY;
						
						//Aply incremental impulse
						//P1 = d.x * normal;
						P1X = dX * normalX;
						P1Y = dX * normalY;
						//P2 = d.y * normal;
						P2X = dY * normalX;
						P2Y = dY * normalY;
						
						//vA -= invMassA * (P1 + P2)
						vA.x -= invMassA * (P1X + P2X);
						vA.y -= invMassA * (P1Y + P2Y);
						//wA -= invIA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2));
						wA -= invIA * ( cp1.rA.x * P1Y - cp1.rA.y * P1X + cp2.rA.x * P2Y - cp2.rA.y * P2X);
						
						//vB += invMassB * (P1 + P2)
						vB.x += invMassB * (P1X + P2X);
						vB.y += invMassB * (P1Y + P2Y);
						//wB += invIB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2));
						wB   += invIB * ( cp1.rB.x * P1Y - cp1.rB.y * P1X + cp2.rB.x * P2Y - cp2.rB.y * P2X);
						
						// Accumulate
						cp1.normalImpulse = xX;
						cp2.normalImpulse = xY;
						
	//#if B2_DEBUG_SOLVER == 1
	//					// Post conditions
	//					//dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA);
	//					dv1X = vB.x - wB * cp1.rB.y - vA.x + wA * cp1.rA.y;
	//					dv1Y = vB.y + wB * cp1.rB.x - vA.y - wA * cp1.rA.x;
	//					//dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA);
	//					dv1X = vB.x - wB * cp2.rB.y - vA.x + wA * cp2.rA.y;
	//					dv1Y = vB.y + wB * cp2.rB.x - vA.y - wA * cp2.rA.x;
	//					// Compute normal velocity
	//					//vn1 = b2Dot(dv1, normal);
	//					vn1 = dv1X * normalX + dv1Y * normalY;
	//					//vn2 = b2Dot(dv2, normal);
	//					vn2 = dv2X * normalX + dv2Y * normalY;
	//
	//					//b2Settings.b2Assert(b2Abs(vn1 - cp1.velocityBias) < k_errorTol);
	//					//b2Settings.b2Assert(b2Abs(vn2 - cp2.velocityBias) < k_errorTol);
	//#endif
						break;
					}
					
					// No solution, give up. This is hit sometimes, but it doesn't seem to matter.
					break;
				}
			}
			
			
			// b2Vec2s in AS3 are copied by reference. The originals are 
			// references to the same things here and there is no need to 
			// copy them back, unlike in C++ land where b2Vec2s are 
			// copied by value.
			/*bodyA->m_linearVelocity = vA;
			bodyB->m_linearVelocity = vB;*/
			bodyA.m_angularVelocity = wA;
			bodyB.m_angularVelocity = wB;
		}
	}
	
	public function finalizeVelocityConstraints() : Void
	{
		for (i in 0...m_constraintCount)
		{
			var c:B2ContactConstraint = m_constraints[ i ];
			var m:B2Manifold = c.manifold;
			
			for (j in 0...c.pointCount)
			{
				var point1:B2ManifoldPoint = m.m_points[j];
				var point2:B2ContactConstraintPoint = c.points[j];
				point1.m_normalImpulse = point2.normalImpulse;
				point1.m_tangentImpulse = point2.tangentImpulse;
			}
		}
	}
	
//#if 1
// Sequential solver
//	public function SolvePositionConstraints(baumgarte:Float):Bool{
//		var minSeparation:Float = 0.0;
//		
//		var tMat:B2Mat22;
//		var tVec:B2Vec2;
//		
//		for (var i:Int = 0; i < m_constraintCount; ++i)
//		{
//			var c:B2ContactConstraint = m_constraints[ i ];
//			var bodyA:B2Body = c.bodyA;
//			var bodyB:B2Body = c.bodyB;
//			var bA_sweep_c:B2Vec2 = bodyA.m_sweep.c;
//			var bA_sweep_a:Float = bodyA.m_sweep.a;
//			var bB_sweep_c:B2Vec2 = bodyB.m_sweep.c;
//			var bB_sweep_a:Float = bodyB.m_sweep.a;
//			
//			var invMassa:Float = bodyA.m_mass * bodyA.m_invMass;
//			var invIa:Float = bodyA.m_mass * bodyA.m_invI;
//			var invMassb:Float = bodyB.m_mass * bodyB.m_invMass;
//			var invIb:Float = bodyB.m_mass * bodyB.m_invI;
//			//var normal:B2Vec2 = new B2Vec2(c.normal.x, c.normal.y);
//			var normalX:Float = c.normal.x;
//			var normalY:Float = c.normal.y;
//			
//			// Solver normal constraints
//			var tCount:Int = c.pointCount;
//			for (var j:Int = 0; j < tCount; ++j)
//			{
//				var ccp:B2ContactConstraintPoint = c.points[ j ];
//				
//				//r1 = b2Mul(bodyA->m_xf.R, ccp->localAnchor1 - bodyA->GetLocalCenter());
//				tMat = bodyA.m_xf.R;
//				tVec = bodyA.m_sweep.localCenter;
//				var r1X:Float = ccp.localAnchor1.x - tVec.x;
//				var r1Y:Float = ccp.localAnchor1.y - tVec.y;
//				tX =  (tMat.col1.x * r1X + tMat.col2.x * r1Y);
//				r1Y = (tMat.col1.y * r1X + tMat.col2.y * r1Y);
//				r1X = tX;
//				
//				//r2 = b2Mul(bodyB->m_xf.R, ccp->localAnchor2 - bodyB->GetLocalCenter());
//				tMat = bodyB.m_xf.R;
//				tVec = bodyB.m_sweep.localCenter;
//				var r2X:Float = ccp.localAnchor2.x - tVec.x;
//				var r2Y:Float = ccp.localAnchor2.y - tVec.y;
//				var tX:Float =  (tMat.col1.x * r2X + tMat.col2.x * r2Y);
//				r2Y = 			 (tMat.col1.y * r2X + tMat.col2.y * r2Y);
//				r2X = tX;
//				
//				//b2Vec2 p1 = bodyA->m_sweep.c + r1;
//				var p1X:Float = b1_sweep_c.x + r1X;
//				var p1Y:Float = b1_sweep_c.y + r1Y;
//				
//				//b2Vec2 p2 = bodyB->m_sweep.c + r2;
//				var p2X:Float = b2_sweep_c.x + r2X;
//				var p2Y:Float = b2_sweep_c.y + r2Y;
//				
//				//var dp:B2Vec2 = b2Math.SubtractVV(p2, p1);
//				var dpX:Float = p2X - p1X;
//				var dpY:Float = p2Y - p1Y;
//				
//				// Approximate the current separation.
//				//var separation:Float = b2Math.b2Dot(dp, normal) + ccp.separation;
//				var separation:Float = (dpX*normalX + dpY*normalY) + ccp.separation;
//				
//				// Track max constraint error.
//				minSeparation = b2Math.b2Min(minSeparation, separation);
//				
//				// Prevent large corrections and allow slop.
//				var C:Float =  b2Math.b2Clamp(baumgarte * (separation + b2Settings.b2_linearSlop), -b2Settings.b2_maxLinearCorrection, 0.0);
//				
//				// Compute normal impulse
//				var dImpulse:Float = -ccp.equalizedMass * C;
//				
//				//var P:B2Vec2 = b2Math.MulFV( dImpulse, normal );
//				var PX:Float = dImpulse * normalX;
//				var PY:Float = dImpulse * normalY;
//				
//				//bodyA.m_position.Subtract( b2Math.MulFV( invMass1, impulse ) );
//				b1_sweep_c.x -= invMass1 * PX;
//				b1_sweep_c.y -= invMass1 * PY;
//				b1_sweep_a -= invI1 * (r1X * PY - r1Y * PX);//b2Math.b2CrossVV(r1, P);
//				bodyA.m_sweep.a = b1_sweep_a;
//				bodyA.SynchronizeTransform();
//				
//				//bodyB.m_position.Add( b2Math.MulFV( invMass2, P ) );
//				b2_sweep_c.x += invMass2 * PX;
//				b2_sweep_c.y += invMass2 * PY;
//				b2_sweep_a += invI2 * (r2X * PY - r2Y * PX);//b2Math.b2CrossVV(r2, P);
//				bodyB.m_sweep.a = b2_sweep_a;
//				bodyB.SynchronizeTransform();
//			}
//			// Update body rotations
//			//bodyA.m_sweep.a = b1_sweep_a;
//			//bodyB.m_sweep.a = b2_sweep_a;
//		}
//		
//		// We can't expect minSpeparation >= -b2_linearSlop because we don't
//		// push the separation above -b2_linearSlop.
//		return minSeparation >= -1.5 * b2Settings.b2_linearSlop;
//	}
//#else
	// Sequential solver.
	private static var s_psm:B2PositionSolverManifold = new B2PositionSolverManifold();
	public function solvePositionConstraints(baumgarte:Float):Bool
	{
		var minSeparation:Float = 0.0;
		
		for (i in 0...m_constraintCount)
		{
			var c:B2ContactConstraint = m_constraints[i];
			var bodyA:B2Body = c.bodyA;
			var bodyB:B2Body = c.bodyB;
			
			var invMassA:Float = bodyA.m_mass * bodyA.m_invMass;
			var invIA:Float = bodyA.m_mass * bodyA.m_invI;
			var invMassB:Float = bodyB.m_mass * bodyB.m_invMass;
			var invIB:Float = bodyB.m_mass * bodyB.m_invI;
			
			
			s_psm.initialize(c);
			var normal:B2Vec2 = s_psm.m_normal;
			
			// Solve normal constraints
			for (j in 0...c.pointCount)
			{
				var ccp:B2ContactConstraintPoint = c.points[j];
				
				var point:B2Vec2 = s_psm.m_points[j];
				var separation:Float = s_psm.m_separations[j];
				
				var rAX:Float = point.x - bodyA.m_sweep.c.x;
				var rAY:Float = point.y - bodyA.m_sweep.c.y;
				var rBX:Float = point.x - bodyB.m_sweep.c.x;
				var rBY:Float = point.y - bodyB.m_sweep.c.y;
				
				// Track max constraint error.
				minSeparation = minSeparation < separation?minSeparation:separation;
				
				// Prevent large corrections and allow slop.
				var C:Float = B2Math.clamp(baumgarte * (separation + B2Settings.b2_linearSlop), -B2Settings.b2_maxLinearCorrection, 0.0);
				
				// Compute normal impulse
				var impulse:Float = -ccp.equalizedMass * C;
				
				var PX:Float = impulse * normal.x;
				var PY:Float = impulse * normal.y;
				
				//bodyA.m_sweep.c -= invMassA * P;
				bodyA.m_sweep.c.x -= invMassA * PX;
				bodyA.m_sweep.c.y -= invMassA * PY;
				//bodyA.m_sweep.a -= invIA * b2Cross(rA, P);
				bodyA.m_sweep.a -= invIA * (rAX * PY - rAY * PX);
				bodyA.synchronizeTransform();
				
				//bodyB.m_sweep.c += invMassB * P;
				bodyB.m_sweep.c.x += invMassB * PX;
				bodyB.m_sweep.c.y += invMassB * PY;
				//bodyB.m_sweep.a += invIB * b2Cross(rB, P);
				bodyB.m_sweep.a += invIB * (rBX * PY - rBY * PX);
				bodyB.synchronizeTransform();
			}
		}
		
		// We can't expect minSpeparation >= -b2_linearSlop because we don't
		// push the separation above -b2_linearSlop.
		return minSeparation > -1.5 * B2Settings.b2_linearSlop;
	}
	
//#endif
	private var m_step:B2TimeStep;
	private var m_allocator:Dynamic;
	public var m_constraints:Array <B2ContactConstraint>;
	private var m_constraintCount:Int = 0;
}
