xquery version "1.0-ml";

module namespace facet = "http://marklogic.com/others-where-constraint";

import module namespace impl = "http://marklogic.com/appservices/search-impl" at "/MarkLogic/appservices/search/search-impl.xqy";
import schema namespace opt = "http://marklogic.com/appservices/search" at "search.xsd";

declare namespace search = "http://marklogic.com/appservices/search";
declare namespace searchdev = "http://marklogic.com/appservices/search/searchdev";
declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $parsed-queries := map:map();

declare function facet:parse-structured(
  $query-elem as element(),
  $options as element(search:options)
)
  as schema-element(cts:query)
{
  (: pull parameters from $query-elem :)
  let $constraint-name as xs:string := $query-elem/search:constraint-name
  let $terms as xs:string* := $query-elem//(search:text, search:value)

  (: take appropriate constraint from full $options :)
  let $constraint := $options/search:constraint[@name eq $constraint-name]

  (: pull real constraint def from annotation :)
  let $real-constraint := facet:_get-real-constraint( $constraint )

  (: reconstruct full options, but with $real-constraint :)
  let $real-options :=
    element { node-name($options) } {
      $options/@*,
      $options/node()[@name != $constraint-name],
      $real-constraint
    }

  (: loop through to search impl for parse (passing through tokens, because we jump into processing of the AST) :)
  (: FIXME: no better way of doing this? :)
  let $toks := (
    <searchdev:tok type="term">{ $constraint-name }</searchdev:tok>,
    <searchdev:tok type="joiner"><search:joiner strength="50" apply="constraint">:</search:joiner></searchdev:tok>,
    for $term in $terms
    return
      <searchdev:tok type="term">{ $term }</searchdev:tok>
  )
  let $query := impl:parse($toks, $real-options, 0)

  (: keep track of what query comes from which constraint :)
  let $_ := map:put($parsed-queries, $constraint-name, (map:get($parsed-queries, $constraint-name), $query))

  (: return the query :)
  return $query
};

declare function facet:start(
  $constraint as element(search:constraint),
  $query as cts:query?,
  $facet-options as xs:string*,
  $quality-weight as xs:double?,
  $forests as xs:unsignedLong*
)
  as item()*
{
  (: check if there are sub-queries for this constraint :)
  let $parsed := map:get($parsed-queries, $constraint/@name)

  (: exclude sub-queries for this constraint from overall query :)
  let $filtered-query :=
    if ($parsed) then
      facet:_filter-query( $query, $parsed )
    else
      $query

  (: pull real constraint def from annotation :)
  let $real-constraint := facet:_get-real-constraint( $constraint )

  (: and loop through to search impl for start-facet :)
  let $buckets :=
    if ( $real-constraint/opt:range[opt:bucket|opt:computed-bucket] ) then
      impl:resolve-buckets($real-constraint)
    else ()
  return
    impl:start-facet(
      $real-constraint,
      $buckets,
      $filtered-query,
      $quality-weight,
      $forests
    )
};

declare function facet:finish(
  $start as item()*,
  $constraint as element(search:constraint),
  $query as cts:query?,
  $facet-options as xs:string*,
  $quality-weight as xs:double?,
  $forests as xs:unsignedLong*
)
  as element(search:facet)
{
  (: check if there are sub-queries for this constraint :)
  let $parsed := map:get($parsed-queries, $constraint/@name)

  (: exclude sub-queries for this constraint from overall query :)
  let $filtered-query :=
    if ($parsed) then
      facet:_filter-query( $query, $parsed )
    else
      $query

  (: pull real constraint def from annotation :)
  let $real-constraint := facet:_get-real-constraint( $constraint )

  (: and loop through to search impl for start-facet :)
  let $buckets :=
    if ( $real-constraint/opt:range[opt:bucket|opt:computed-bucket] ) then
      impl:resolve-buckets($real-constraint)
    else ()
  return
    impl:finish-facet(
      $real-constraint,
      $buckets,
      $start,
      $filtered-query,
      $quality-weight,
      $forests
    )
};

declare private function facet:_intersect( $left, $right ) {
  let $r := $right ! xdmp:quote($right)
  for $l in $left ! xdmp:quote($left)
  where $l = $r
  return $l
};

declare private function facet:_filter-query( $queries, $exclude-queries ) {
  for $query in $queries
  return typeswitch ($query)
  case cts:and-query
    return cts:and-query(
      facet:_filter-query(cts:and-query-queries($query), $exclude-queries),
      cts:and-query-options($query)
    )
  case cts:or-query
    return cts:or-query(
      facet:_filter-query(cts:or-query-queries($query), $exclude-queries),
      cts:or-query-options($query)
    )
  case cts:not-query
    return cts:not-query(
      facet:_filter-query(cts:not-query-query($query), $exclude-queries),
      cts:not-query-weight($query)
    )
  case cts:near-query
    return cts:near-query(
      facet:_filter-query(cts:near-query-queries($query), $exclude-queries),
      cts:near-query-distance($query),
      cts:near-query-options($query),
      cts:near-query-weight($query)
    )
  default return
    if (facet:_intersect($query, $exclude-queries)) then
      cts:true-query()
    else
      $query
};

declare private function facet:_get-real-constraint(
  $constraint as element(search:constraint)
)
  as element(opt:constraint)
{
  element opt:constraint {
    $constraint/@*,

    for $node in $constraint/search:annotation/*[ empty( self::search:additional-query ) ]
    return
      element { node-name($node) } {
        $node/@*,
        $node/node()
      }
  }
};
