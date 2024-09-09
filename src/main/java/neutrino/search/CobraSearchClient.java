package neutrino.search;

import com.azure.core.util.Context;
import com.azure.search.documents.SearchClient;
import com.azure.search.documents.SearchClientBuilder;
import com.azure.search.documents.models.SearchOptions;
import neutrino.search.model.ScoredKMNR;
import java.util.ArrayList;
import java.util.List;
import com.azure.identity.DefaultAzureCredentialBuilder;

public class CobraSearchClient {
    /**
     * From the Azure portal, get your Azure AI Search service URL and API key,
     * and set the values of these variables:
     */
    private static final String SEARCH_ENDPOINT = "https://cobraais-pzkll4f77jauu.search.windows.net/";
    private static final String SEARCH_INDEX = "cobraidx";
    private final SearchClient searchClient;

    public CobraSearchClient() {
        this.searchClient = createSearchClient();
    }

    // create search client
    // assumes a search service and index have been created
    private SearchClient createSearchClient() {
        return new SearchClientBuilder()
            .endpoint(SEARCH_ENDPOINT)
            .indexName(SEARCH_INDEX)
            .credential(new DefaultAzureCredentialBuilder().build())
            .buildClient();
    }

    // get search client
    public SearchClient getSearchClient() {
        return searchClient;
    }

    // perform search
    public List<ScoredKMNR> search(String searchText) {
        System.out.println("Searching for: " + searchText);

        SearchOptions options = new SearchOptions();
        options.setTop(5);

        var searchResults = searchClient.search(searchText, options, Context.NONE);

        List<ScoredKMNR> results = new ArrayList<ScoredKMNR>();
        for (var result : searchResults)
        {
            ScoredKMNR scoredKMNR = result.getDocument(ScoredKMNR.class);
            results.add(scoredKMNR);
        }

        return results;
    }


}