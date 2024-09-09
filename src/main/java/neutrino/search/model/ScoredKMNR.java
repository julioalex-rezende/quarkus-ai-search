package neutrino.search.model;

import lombok.Getter;
import lombok.Setter;
import lombok.Builder;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@Setter
@Builder
@NoArgsConstructor
public class ScoredKMNR {

    private String id;
    private String summary;
    private String description;
    private String type;
    private String url;
    private List<String> module_orgs; 
}