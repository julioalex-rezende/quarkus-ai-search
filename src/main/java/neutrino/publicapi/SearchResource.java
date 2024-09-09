package neutrino.publicapi;

import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.Status;
import neutrino.search.CobraSearchClient;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Path("/search")
public class SearchResource {

    private static Logger logger = LoggerFactory.getLogger(SearchResource.class);
    private CobraSearchClient searchClient;

    public SearchResource() {
        searchClient = new CobraSearchClient();
    }

    @POST
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    public Response search(Map<String, Object> requestJson) {
        String searchText = (String) requestJson.get("query");
        if (searchText == null) {
            return Response.status(Status.BAD_REQUEST).entity(Map.of("error", "Missing 'query' parameter")).build();
        }

        Integer topK = ((Number) requestJson.getOrDefault("top_k", 5)).intValue();
        String type = (String) requestJson.get("type");
        List<String> moduleOrgs = getCommaSeparatedParams(requestJson.get("module_orgs"));
        List<String> derivatives = getCommaSeparatedParams(requestJson.get("derivatives"));
        List<String>  buildPhases = getCommaSeparatedParams(requestJson.get("build_phases"));
        String expertName = (String) requestJson.get("expert_name");
        String retrievalMode = ((String) requestJson.getOrDefault("retrieval_mode", "TEXT")).toUpperCase();
        String indexName = (String) requestJson.getOrDefault("index_name", System.getenv("AZURE_SEARCH_INDEX"));

        String msg = 
            """
                Searching for '%s'
                in index '%s' with
                top_k = %d, 
                type = %s,
                module_orgs = %s, 
                derivatives = %s, 
                build_phases = %s
                retrieval_mode=s minimum_search_score=f
            """
            .formatted(searchText, indexName, topK, type, moduleOrgs, 
                            derivatives, buildPhases, retrievalMode, expertName);

        logger.info(msg);          
        
        var searchResults = searchClient.search(searchText);

        return Response.ok(searchResults).build();
    }

    public List<String> getCommaSeparatedParams(Object param) {
        if (param == null) {
            return null;
        }
        if ( param instanceof List) {
            return (List<String>) param;
        }
        if (param instanceof String) {
            return Arrays.asList(((String) param).split(","));
        }

        // shouldn't happen
        throw new IllegalArgumentException("Expected a string or list of strings");

    }

}