﻿//---------------------------------------------------------------------
// <copyright file="StarTokenTests.cs" company="Microsoft">
//      Copyright (C) Microsoft Corporation. All rights reserved. See License.txt in the project root for license information.
// </copyright>
//---------------------------------------------------------------------

using Microsoft.OData.UriParser;
using Xunit;

namespace Microsoft.OData.Tests.UriParser.SyntacticAst
{
    public class StarTokenTests
    {
        [Fact]
        public void ParentCanBeNull()
        {
            StarToken starToken = new StarToken(null);
            Assert.Null(starToken.NextToken);
        }

        [Fact]
        public void ParentIsSetCorrectly()
        {
            StarToken starToken = new StarToken(new LiteralToken(1));
            starToken.NextToken.ShouldBeLiteralQueryToken(1);
        }

        [Fact]
        public void NameIsAlwaysStar()
        {
            StarToken starToken = new StarToken(null);
            Assert.Equal("*", starToken.Identifier);
        }
    }
}
