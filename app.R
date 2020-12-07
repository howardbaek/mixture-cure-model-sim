library(tidyverse)
library(shiny)
library(kableExtra)
library(survminer)
library(flexsurvcure)


output_df <- read_csv("final_df.csv") %>% 
  select(-max_unif) %>% 
  mutate_at(1:3, round, 3)

ui <- fluidPage(
  
  titlePanel(tagList(
    span("Simulation of a Parametric Mixture Cure Model",
         span(
           actionButton("github",
                        label = "Code",
                        icon = icon("github"),
                        width = "80px",
                        onclick ="window.open(`https://github.com/howardbaek/nhl-pbp`, '_blank')",
                        style="color: #fff; background-color: #767676; border-color: #767676"),
           style = "position:absolute;right:2em;")
    )
  ),
  windowTitle = "Cure Model Simulation"),
  
  hr(),
  br(),
  
  sidebarLayout(
    
    sidebarPanel(
      
      selectInput("sample_size", "Sample Size", c(10, 100, 1000)),
      selectInput("hazard_rate", "Hazard Rate", c(1, 1.5, 2, 5)),
      selectInput("cure_fraction", "Cure Fraction", c(0, 0.2, 0.5, 0.8)),
      
      br(),
      
      actionButton("run_simulation", "Run Simulation",
                   icon("running"), style="color: #fff; background-color: #337ab7; border-color: #2e6da4"),
      
      actionButton("generate_plot", "Generate Plot",
                   icon("image"), style="color: #fff; background-color: #337ab7; border-color: #2e6da4")
    ),
    
    mainPanel(
      
      plotOutput("survival_plot"),  
      
      br(),
      
      tableOutput("table_output")
      
      
    )
  )
)



server <- function(input, output) {
  
  data <- eventReactive(input$run_simulation, {
    
    output_df %>% 
      filter(sample_size == input$sample_size,
             hazard_rate == input$hazard_rate,
             cure_fraction == input$cure_fraction) %>% 
      kbl(col.names = c("Hazard Ratio (Cox)", "Odds Ratio (Cure)",
                        "Hazard Ratio (Cure)", "Sample Size", 
                        "True Hazard Ratio", "True Cure Fraction"),
          caption = "Sample Output for  Mixture Cure Model") %>%
      kable_classic(full_width = F, html_font = "Cambria") %>% 
      footnote(general = "Odds ratios greater than 1 indicate an increase in the proportion of long-term survivors and hazard ratios less than 1 indicate an improvement in survival among patients who are not long-term survivors")
    
    
    
  })
  
  
  ## Model Output Table-----------------
  output$table_output <- function() {
    
    data()
    
  }
  
  
  
  km_plot <- eventReactive(input$generate_plot, {
    
    
    # Uniformly distributed vector u (inverse cdf method)
    u_1 <- runif(input$sample_size)
    
    # Group 1 (Base hazard rate of 1 and base cure fraction of 0)
    first_group_event <- ifelse(!is.na(qexp(u_1 / (1- 0), 1)), qexp(u_1 / (1- 0), 1), Inf)
    first_group_censor <- runif(input$sample_size, min = 0, max = 1)
    first_obs_time <- pmin(first_group_event, first_group_censor)
    first_status <- as.numeric(first_group_censor > first_group_event) # 1 if event occurs and 0 if event is censored
    
    
    # Uniformly distributed vector u (inverse cdf method)
    u_2 <- runif(input$sample_size)
    
    # Group 2 (varying hazard rates)
    second_group_event <- ifelse(!is.nan(qexp(u_2 / (1- as.numeric(input$cure_fraction)), as.numeric(input$hazard_rate))), 
                                 qexp(u_2 / (1- as.numeric(input$cure_fraction)), as.numeric(input$hazard_rate)), Inf)
    second_group_censor <- runif(input$sample_size, min = 0, max = 1)
    second_obs_time <- pmin(second_group_event, second_group_censor)
    second_status <- as.numeric(second_group_censor > second_group_event) # 1 if event occurs and 0 if event is censored
    
    
    # Put the above into our desired dataset (ready to put into Surv())
    df <- data.frame(time = c(first_obs_time, second_obs_time),
                     status = c(first_status, second_status),
                     x = c(rep("first", times = input$sample_size),
                           rep("second", times = input$sample_size)))
    
    
    # Fit Cox Proportional Model
    coxph_model <- survival::survfit(Surv(time = time, event = status) ~ x, data = df) 
    
    ggsurvplot(coxph_model,
               data = df,
               legend.labs = c("Base Group", "Group with Varying Hazard Rate and Cure Fraction"),
               legend.title = "Groups")
    
  })
  
  
  
  ## Model Output Table-----------------
  output$survival_plot <- renderPlot({
    
    km_plot()
    
  })
  
  
  
  
  
}

shinyApp(ui, server)