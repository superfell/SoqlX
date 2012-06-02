// RRUtils RRExponentialFunction.m
//
// Copyright © 2008, Roy Ratcliffe, Lancaster, United Kingdom
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------

#import "RRExponentialFunction.h"

#import <math.h> // for expf

void RRExponentialFunctionSetCoefficient(RRExponentialFunction *f, float c)
{
	f->coefficient = c;
	f->exponentOfMinusCoefficient = expf(-c);
	f->oneOverOneMinusExponentOfMinusCoefficient = 1.0f / (1.0f - f->exponentOfMinusCoefficient);
	// Computing "one over one minus exponent of minus coefficient" optimises
	// for multiplication over division. Effectively, the exponential function
	// divides by one minus the exponent of the coefficient. Deriving the
	// reciprocal upfront changes the divide to multiply during
	// evaluation. Multiply typically beats divide when it comes to performance.
}

float RRExponentialFunctionEvaluate(RRExponentialFunction *f, float x)
{
	return 1.0f - ((expf(x * -f->coefficient) - f->exponentOfMinusCoefficient) * f->oneOverOneMinusExponentOfMinusCoefficient);
}
