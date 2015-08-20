# ml-constraints

Pre-built custom search constraints that go beyond what the MarkLogic REST API provides OOTB

## Install

Installation depends on the [MarkLogic Package Manager](https://github.com/joemfb/mlpm):

```
$ mlpm install ml-constraint --save
$ mlpm deploy
```


## additional-query-constraint

This custom constraint can be wrapped around any existing search constraint to apply an additional query that only applies to that search constraint (and its facet values).

### Usage

Take an existing search constraint in your REST api query options, and put the following after the open tag `<constraint name="myconstraint">`:

    <custom>
      <parse apply="parse-structured" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
      <start-facet apply="start" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
      <finish-facet apply="finish" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
    </custom>
    <annotation>

Put the following before the closing tag `</constraint>`:

      <additional-query>
      </additional-query>
    </annotation>

Inside additional query you can insert any serialized cts:query, for instance a cts:collection-query:

    <cts:collection-query xmlns:cts="http://marklogic.com/cts">
      <cts:uri>examples</cts:uri>
    </cts:collection-query>

E.g. this:

    <constraint name="myconstraint">
    
      <range collation="http://marklogic.com/collation/" type="xs:string" facet="true">
        <element ns="http://some-ns.com/example" name="myexample"/>
        <facet-option>frequency-order</facet-option>
        <facet-option>descending</facet-option>
        <facet-option>limit=10</facet-option>
      </range>
    
    </constraint>

would become:

    <constraint name="myconstraint">
      <custom>
        <parse apply="parse-structured" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
        <start-facet apply="start" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
        <finish-facet apply="finish" ns="http://marklogic.com/additional-query-constraint" at="/ext/mlpm_modules/ml-constraints/additional-query-constraint.xqy"/>
      </custom>
      <annotation>
      
        <range collation="http://marklogic.com/collation/" type="xs:string" facet="true">
          <element ns="http://some-ns.com/example" name="myexample"/>
          <facet-option>frequency-order</facet-option>
          <facet-option>descending</facet-option>
          <facet-option>limit=10</facet-option>
        </range>
        
        <additional-query>
          <cts:collection-query xmlns:cts="http://marklogic.com/cts">
            <cts:uri>examples</cts:uri>
          </cts:collection-query>
        </additional-query>
      </annotation>
    </constraint>

### Known issues

- This constraint only implements a parse-structured method, and is therefore only supported by the REST api. The parse-string approach does not pass through the full query options, which is essential in this case
- Custom constraints currently only support `EQ` comparison, e.g. `myconstraint:somevalue`, and **not** `myconstraint GT somevalue` (RFE has been filed)
- Due to a bug/limitation of the REST api parse-structured-style constraint are not supported by /v1/suggest

