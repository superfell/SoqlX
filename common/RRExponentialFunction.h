// RRUtils RRExponentialFunction.h
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

// Encapsulates an optimising generic Exponential Function where
//		y=1-(exp(x*-c)-exp(-c))/(1-exp(-c))
// and where 0<c is a general coefficient describing the exponential
// curvature. The function's input domain lies within the 0..1 interval, its
// output range likewise. The implementation optimises by pre-computing those
// constant terms depending only on the coefficient whenever the coefficient
// changes. Repeated evaluation takes less computing time thereafter.
struct RRExponentialFunction
{
	float coefficient;
	float exponentOfMinusCoefficient;
	float oneOverOneMinusExponentOfMinusCoefficient;
};

typedef struct RRExponentialFunction RRExponentialFunction;

void RRExponentialFunctionSetCoefficient(RRExponentialFunction *f, float c);
float RRExponentialFunctionEvaluate(RRExponentialFunction *f, float x);
