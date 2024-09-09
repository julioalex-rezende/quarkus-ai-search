package neutrino.search.enums;

public enum RetrievalMode {
    TEXT("text"),
    VECTOR("vector"),
    HYBRID("hybrid");

    private final String value;

    private RetrievalMode(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}