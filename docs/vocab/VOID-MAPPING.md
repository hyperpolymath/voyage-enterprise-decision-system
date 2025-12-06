# VEDS VoID Vocabulary Integration

## Overview

VoID (Vocabulary of Interlinked Datasets) is an RDF vocabulary for describing datasets and their relationships. VEDS uses VoID to:

1. **Describe datasets** - Metadata about our transport network, decisions, tracking data
2. **Enable discoverability** - Allow external systems to find and understand VEDS data
3. **Support federation** - Link to external datasets (ports, countries, carbon factors)
4. **Document provenance** - Track where data comes from

---

## VEDS as a VoID Dataset

```turtle
@prefix void:    <http://rdfs.org/ns/void#> .
@prefix dct:     <http://purl.org/dc/terms/> .
@prefix foaf:    <http://xmlns.com/foaf/0.1/> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .
@prefix veds:    <https://veds.example.org/vocab#> .
@prefix vedsdat: <https://veds.example.org/data/> .
@prefix geo:     <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix schema:  <http://schema.org/> .

# ==============================================================================
# VEDS Root Dataset
# ==============================================================================

vedsdat:root a void:Dataset ;
    dct:title "Voyage Enterprise Decision System"@en ;
    dct:description "Multimodal transport optimization with formal verification"@en ;
    dct:publisher vedsdat:publisher ;
    dct:license <https://opensource.org/licenses/MIT> ;
    dct:created "2025-12-06"^^xsd:date ;
    dct:modified "2025-12-06"^^xsd:date ;

    # Access points
    void:sparqlEndpoint <https://veds.example.org/sparql> ;
    void:dataDump <https://veds.example.org/dumps/latest.nq.gz> ;
    void:uriLookupEndpoint <https://veds.example.org/lookup?uri=> ;

    # Technical details
    void:feature <http://www.w3.org/ns/formats/N-Quads> ;  # bitemporality
    void:vocabulary veds: , geo: , schema: ;

    # Subsets
    void:subset vedsdat:transport-network ;
    void:subset vedsdat:decisions ;
    void:subset vedsdat:tracking ;
    void:subset vedsdat:constraints .

vedsdat:publisher a foaf:Organization ;
    foaf:name "VEDS Project" ;
    foaf:homepage <https://veds.example.org> .

# ==============================================================================
# Transport Network Dataset
# ==============================================================================

vedsdat:transport-network a void:Dataset ;
    dct:title "VEDS Transport Network"@en ;
    dct:description "Graph of transport nodes (ports, terminals) and edges (routes)"@en ;

    # Statistics
    void:triples 5000000 ;
    void:entities 55000 ;
    void:classes 8 ;
    void:properties 45 ;

    # Classes used
    void:classPartition [
        void:class veds:TransportNode ;
        void:entities 5000 ;
    ] ;
    void:classPartition [
        void:class veds:TransportEdge ;
        void:entities 50000 ;
    ] ;
    void:classPartition [
        void:class veds:Port ;
        void:entities 5000 ;
    ] ;
    void:classPartition [
        void:class veds:Carrier ;
        void:entities 500 ;
    ] ;

    # Property usage
    void:propertyPartition [
        void:property geo:lat ;
        void:triples 5000 ;
    ] ;
    void:propertyPartition [
        void:property geo:long ;
        void:triples 5000 ;
    ] ;
    void:propertyPartition [
        void:property veds:distanceKm ;
        void:triples 50000 ;
    ] ;
    void:propertyPartition [
        void:property veds:carbonPerTonneKm ;
        void:triples 50000 ;
    ] ;

    # External links
    void:linkset vedsdat:ports-to-unlocode ;
    void:linkset vedsdat:countries-to-iso ;
    void:linkset vedsdat:carriers-to-lei .

# ==============================================================================
# Linksets (Connections to External Datasets)
# ==============================================================================

vedsdat:ports-to-unlocode a void:Linkset ;
    dct:title "VEDS Ports to UN/LOCODE"@en ;
    void:linkPredicate owl:sameAs ;
    void:subjectsTarget vedsdat:transport-network ;
    void:objectsTarget <https://unece.org/trade/uncefact/unlocode> ;
    void:triples 5000 .

vedsdat:countries-to-iso a void:Linkset ;
    dct:title "VEDS Countries to ISO 3166"@en ;
    void:linkPredicate owl:sameAs ;
    void:subjectsTarget vedsdat:transport-network ;
    void:objectsTarget <https://www.iso.org/iso-3166-country-codes.html> ;
    void:triples 200 .

vedsdat:carriers-to-lei a void:Linkset ;
    dct:title "VEDS Carriers to LEI Registry"@en ;
    dct:description "Links to Legal Entity Identifiers for carrier companies"@en ;
    void:linkPredicate schema:leiCode ;
    void:subjectsTarget vedsdat:transport-network ;
    void:objectsTarget <https://www.gleif.org/lei/> ;
    void:triples 500 .

vedsdat:carbon-factors-to-icct a void:Linkset ;
    dct:title "Carbon emission factors from ICCT"@en ;
    void:linkPredicate dct:source ;
    void:subjectsTarget vedsdat:transport-network ;
    void:objectsTarget <https://theicct.org/> ;
    void:triples 50 .

# ==============================================================================
# Decision Audit Dataset (Bitemporal)
# ==============================================================================

vedsdat:decisions a void:Dataset ;
    dct:title "VEDS Decision Audit Trail"@en ;
    dct:description "Bitemporal record of all routing decisions with proofs"@en ;

    # Bitemporal feature
    void:feature <http://www.w3.org/ns/formats/N-Quads> ;
    void:feature veds:BitemporalStorage ;

    # Statistics (approximate, grows over time)
    void:triples 10000000 ;
    void:entities 1000000 ;

    # Classes
    void:classPartition [
        void:class veds:Decision ;
        void:entities 500000 ;
    ] ;
    void:classPartition [
        void:class veds:ConstraintEvaluation ;
        void:entities 2500000 ;
    ] ;
    void:classPartition [
        void:class veds:ProofCertificate ;
        void:entities 500000 ;
    ] ;
    void:classPartition [
        void:class veds:AuditEntry ;
        void:entities 100000 ;
    ] ;

    # Temporal properties
    void:propertyPartition [
        void:property veds:validTime ;
        void:triples 4000000 ;
    ] ;
    void:propertyPartition [
        void:property veds:transactionTime ;
        void:triples 4000000 ;
    ] .

# ==============================================================================
# Tracking Dataset (High-Volume Time-Series)
# ==============================================================================

vedsdat:tracking a void:Dataset ;
    dct:title "VEDS Real-Time Tracking"@en ;
    dct:description "Live position and status updates for shipments"@en ;

    # High-volume characteristics
    void:triples 100000000 ;  # grows rapidly

    # Retention policy
    veds:retentionDays 90 ;
    veds:archivePolicy "S3 Glacier after 90 days"@en ;

    # Classes
    void:classPartition [
        void:class veds:Position ;
        void:entities 50000000 ;
    ] ;
    void:classPartition [
        void:class veds:TrackingEvent ;
        void:entities 10000000 ;
    ] ;
    void:classPartition [
        void:class veds:EtaUpdate ;
        void:entities 40000000 ;
    ] .

# ==============================================================================
# Constraint Dataset
# ==============================================================================

vedsdat:constraints a void:Dataset ;
    dct:title "VEDS Constraint Definitions"@en ;
    dct:description "Business rules, labor standards, carbon budgets"@en ;

    void:triples 10000 ;
    void:entities 500 ;

    # Constraint types
    void:classPartition [
        void:class veds:WageConstraint ;
        void:entities 200 ;  # per-country minimums
    ] ;
    void:classPartition [
        void:class veds:CarbonConstraint ;
        void:entities 50 ;
    ] ;
    void:classPartition [
        void:class veds:HoursConstraint ;
        void:entities 100 ;
    ] ;
    void:classPartition [
        void:class veds:SanctionConstraint ;
        void:entities 50 ;
    ] ;
    void:classPartition [
        void:class veds:CustomConstraint ;
        void:entities 100 ;
    ] ;

    # Links to standards
    void:linkset vedsdat:wages-to-ilo ;
    void:linkset vedsdat:sanctions-to-ofac .

vedsdat:wages-to-ilo a void:Linkset ;
    dct:title "Wage constraints linked to ILO standards"@en ;
    void:linkPredicate dct:conformsTo ;
    void:objectsTarget <https://www.ilo.org/> ;
    void:triples 200 .

vedsdat:sanctions-to-ofac a void:Linkset ;
    dct:title "Sanction constraints linked to OFAC"@en ;
    void:linkPredicate dct:source ;
    void:objectsTarget <https://sanctionssearch.ofac.treas.gov/> ;
    void:triples 50 .
```

---

## VEDS Vocabulary (veds:)

```turtle
@prefix veds:    <https://veds.example.org/vocab#> .
@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl:     <http://www.w3.org/2002/07/owl#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .
@prefix skos:    <http://www.w3.org/2004/02/skos/core#> .

# ==============================================================================
# Core Classes
# ==============================================================================

veds:TransportNode a rdfs:Class ;
    rdfs:label "Transport Node"@en ;
    rdfs:comment "A hub, terminal, or waypoint in the transport network"@en ;
    skos:example "Port of Rotterdam, Frankfurt Rail Terminal" .

veds:TransportEdge a rdfs:Class ;
    rdfs:label "Transport Edge"@en ;
    rdfs:comment "A route connecting two nodes via a specific transport mode"@en .

veds:Port a rdfs:Class ;
    rdfs:subClassOf veds:TransportNode ;
    rdfs:label "Port"@en ;
    rdfs:comment "A seaport, airport, or inland port"@en .

veds:Carrier a rdfs:Class ;
    rdfs:label "Carrier"@en ;
    rdfs:comment "A company operating transport services"@en .

veds:Shipment a rdfs:Class ;
    rdfs:label "Shipment"@en ;
    rdfs:comment "A cargo movement request from origin to destination"@en .

veds:Route a rdfs:Class ;
    rdfs:label "Route"@en ;
    rdfs:comment "An optimized multimodal path for a shipment"@en .

veds:Segment a rdfs:Class ;
    rdfs:label "Segment"@en ;
    rdfs:comment "One leg of a route using a single transport edge"@en .

veds:Constraint a rdfs:Class ;
    rdfs:label "Constraint"@en ;
    rdfs:comment "A business rule that routes must satisfy"@en .

veds:Decision a rdfs:Class ;
    rdfs:label "Decision"@en ;
    rdfs:comment "A recorded routing decision with audit trail"@en .

veds:ProofCertificate a rdfs:Class ;
    rdfs:label "Proof Certificate"@en ;
    rdfs:comment "A formal verification proof that a route satisfies constraints"@en .

# ==============================================================================
# Transport Mode Vocabulary
# ==============================================================================

veds:TransportMode a rdfs:Class ;
    rdfs:label "Transport Mode"@en .

veds:Maritime a veds:TransportMode ;
    rdfs:label "Maritime"@en ;
    skos:definition "Ocean freight via container ships or bulk carriers"@en .

veds:Rail a veds:TransportMode ;
    rdfs:label "Rail"@en ;
    skos:definition "Freight rail including intermodal containers"@en .

veds:Road a veds:TransportMode ;
    rdfs:label "Road"@en ;
    skos:definition "Trucking and road freight"@en .

veds:Air a veds:TransportMode ;
    rdfs:label "Air"@en ;
    skos:definition "Air cargo freight"@en .

# ==============================================================================
# Core Properties
# ==============================================================================

veds:distanceKm a rdf:Property ;
    rdfs:label "distance (km)"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range xsd:decimal .

veds:carbonPerTonneKm a rdf:Property ;
    rdfs:label "carbon per tonne-km (kg CO2)"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Emission factor for this edge"@en .

veds:transitHours a rdf:Property ;
    rdfs:label "transit time (hours)"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range xsd:decimal .

veds:baseCostUsd a rdf:Property ;
    rdfs:label "base cost (USD)"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range xsd:decimal .

veds:mode a rdf:Property ;
    rdfs:label "transport mode"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range veds:TransportMode .

veds:fromNode a rdf:Property ;
    rdfs:label "from node"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range veds:TransportNode .

veds:toNode a rdf:Property ;
    rdfs:label "to node"@en ;
    rdfs:domain veds:TransportEdge ;
    rdfs:range veds:TransportNode .

# Bitemporal properties
veds:validTime a rdf:Property ;
    rdfs:label "valid time"@en ;
    rdfs:comment "When this fact was true in the real world"@en ;
    rdfs:range xsd:dateTime .

veds:transactionTime a rdf:Property ;
    rdfs:label "transaction time"@en ;
    rdfs:comment "When this fact was recorded in the system"@en ;
    rdfs:range xsd:dateTime .

# Labor properties
veds:averageWageCents a rdf:Property ;
    rdfs:label "average wage (cents/hour)"@en ;
    rdfs:domain veds:Carrier ;
    rdfs:range xsd:integer .

veds:unionized a rdf:Property ;
    rdfs:label "unionized"@en ;
    rdfs:domain veds:Carrier ;
    rdfs:range xsd:boolean .

veds:safetyRating a rdf:Property ;
    rdfs:label "safety rating (1-5)"@en ;
    rdfs:domain veds:Carrier ;
    rdfs:range xsd:integer .

# Proof properties
veds:proofStatus a rdf:Property ;
    rdfs:label "proof status"@en ;
    rdfs:domain veds:ProofCertificate ;
    rdfs:range veds:ProofStatusValue .

veds:ProofStatusValue a rdfs:Class .
veds:Proven a veds:ProofStatusValue ; rdfs:label "Proven" .
veds:Timeout a veds:ProofStatusValue ; rdfs:label "Timeout" .
veds:Failed a veds:ProofStatusValue ; rdfs:label "Failed" .
veds:ManuallyApproved a veds:ProofStatusValue ; rdfs:label "Manually Approved" .
```

---

## VoID Discovery Endpoint

VEDS exposes a well-known VoID description at:

```
GET https://veds.example.org/.well-known/void
```

This returns the VoID description in Turtle format, enabling:

1. **Crawler discovery** - Search engines can find our datasets
2. **Federation** - Other systems can understand our schema
3. **Tool support** - VoID-aware tools can generate queries
4. **Documentation** - Human-readable dataset descriptions

---

## Integration with External Vocabularies

| External Vocabulary | Usage in VEDS |
|---------------------|---------------|
| **geo:** (WGS84) | Port and node coordinates |
| **schema.org** | Organization, Place references |
| **dct:** (Dublin Core) | Metadata (title, description, license) |
| **foaf:** | Publisher information |
| **skos:** | Concept definitions |
| **owl:** | Class relationships, sameAs links |
| **prov:** | Provenance tracking |

---

## SPARQL Endpoint Examples

```sparql
# Find all ports in the Netherlands
SELECT ?port ?name ?lat ?lon
WHERE {
  ?port a veds:Port ;
        veds:country <https://veds.example.org/country/NL> ;
        rdfs:label ?name ;
        geo:lat ?lat ;
        geo:long ?lon .
}

# Find routes with low carbon footprint
SELECT ?route ?carbon
WHERE {
  ?route a veds:Route ;
         veds:totalCarbonKg ?carbon .
  FILTER (?carbon < 1000)
}
ORDER BY ?carbon

# Bitemporal query: What did we know on Dec 1 about Dec 5?
SELECT ?decision ?route
WHERE {
  GRAPH ?g {
    ?decision a veds:Decision ;
              veds:route ?route ;
              veds:validTime ?vt ;
              veds:transactionTime ?tt .
  }
  FILTER (?vt = "2025-12-05"^^xsd:date)
  FILTER (?tt <= "2025-12-01"^^xsd:dateTime)
}
```

---

## Publishing VoID Descriptions

### Automated VoID Generation

```clojure
;; Clojure function to generate VoID statistics
(defn generate-void-stats [xtdb-node surrealdb-conn]
  (let [port-count (count-entities surrealdb-conn "port")
        edge-count (count-entities surrealdb-conn "transport_edge")
        decision-count (xt/q xtdb-node '{:find [(count ?d)]
                                          :where [[?d :decision/id _]]})]
    {:entities {:ports port-count
                :edges edge-count
                :decisions (ffirst decision-count)}
     :triples (estimate-triples port-count edge-count decision-count)
     :last-modified (java.time.Instant/now)}))
```

### Scheduled VoID Updates

VoID statistics are regenerated:
- **Hourly** for approximate counts
- **Daily** for full dataset analysis
- **On-demand** via admin API
