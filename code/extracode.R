### Mitotic Activity vs Ki67 Correlation 

KM Curve for the categorical parts of the mitotic activity increase. 

```{r}
# KM curve for mitotic activity 
micat_df <- df %>% filter(mitotic_activity_increase %in% c("0", "1to5", "6to10", ">10"))
micat_df$mitotic_activity_increase <- factor(micat_df$mitotic_activity_increase, levels = c("0", "1to5", "6to10", ">10"))
table(micat_df$mitotic_activity_increase)

micat_df_nz <- df %>% filter(mitotic_activity_increase %in% c("1to5", "6to10", ">10"))
micat_df_nz$mitotic_activity_increase <- factor(micat_df_nz$mitotic_activity_increase, levels = c("1to5", "6to10", ">10"))


mai_km <- survfit2(Surv(overall_survival, status == 1) ~ mitotic_activity_increase, data = micat_df_nz)
ggsurvfit(mai_km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Categorical Mitotic Activity Increase KM Curve"
  )
```

Seeing if there is trend between mitotic activity and Ki67

```{r}
micat_df$Ki67_LI <- factor(micat_df$Ki67_LI, levels = c("<15%", "15%", ">15%"))
micat_df_nz$Ki67_LI <- factor(micat_df_nz$Ki67_LI, levels = c("<15%", "15%", ">15%"))

fisher.test(table(micat_df$mitotic_activity_increase, micat_df$Ki67_LI))
```
There is a slight association between mitotic activity and Ki67. Interaction curve:
  
  ```{r}
micat_df$interaction_group <- interaction(micat_df$mitotic_activity_increase, micat_df$Ki67_LI)
mai_ki_km <- survfit2(Surv(overall_survival, status == 1) ~ interaction_group, data = micat_df)
ggsurvfit(mai_ki_km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival Ki67 + Mitotic Activity Increase"
  )

table(micat_df$interaction_group)

summary(coxph(Surv(overall_survival, status == 1) ~ interaction_group, data = micat_df))
```

### Median Age Analysis

```{r}
median_age <- median(df$diagnosis_age)

df$median_age_status <- cut(df$diagnosis_age,
                            breaks = c(0, 66, 100),  
                            labels = c("Below Median", "Equal to or Above Median"),  
                            right = FALSE)

km_median_age <- survfit2(Surv(overall_survival, status == 1) ~ median_age_status, data = df)
ggsurvfit(km_median_age) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Groups Above and Below Median Age"
  )
```

We see significance here, what about for dividing dataset into thirds?
  
  ```{r}
df$age_thirds <- cut(df$diagnosis_age, 
                     breaks = c(0, 52, 72, 100), 
                     labels = c("31-51", "52-71", "72-91"), 
                     right = FALSE)

km_median_age <- survfit2(Surv(overall_survival, status == 1) ~ age_thirds, data = df)
ggsurvfit(km_median_age) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Age Groups (Thirds)"
  )
```

And fourths? 
  
  ```{r}
df$age_fourths <- cut(df$diagnosis_age, 
                      breaks = c(0, 47, 62, 78, 100), 
                      labels = c("31-46", "47-61", "62-77", "78-91"), 
                      right = FALSE)

km_median_age <- survfit2(Surv(overall_survival, status == 1) ~ age_fourths, data = df)
ggsurvfit(km_median_age) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Age Groups (Fourths)"
  )
```

### MGMT Status 

```{r}
km <- survfit2(Surv(overall_survival, status == 1) ~ MGMT_methylation, data = df)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival by MGMT Status"
  )
```

Benefit of methylated status comes out over time, greater overall survival. 

#### MGMT Treated by Stupps

```{r}
df_stupps <- df %>% filter(received_stupp == "yes")

km <- survfit2(Surv(overall_survival, status == 1) ~ MGMT_methylation, data = df_stupps)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Patients Treated with Stupps by MGMT Status"
  )
```

Overall, when treated with Stupps, median survival time increases.

```{r}
df$stupps_mgmt <- interaction(df$received_stupp, df$MGMT_methylation)

fit <- survfit(Surv(overall_survival, status == 1) ~ stupps_mgmt, data = df)
medians <- surv_median(fit)

medians_df <- data.frame(group = names(summary(fit)$table[, "median"]),
                         median_survival = summary(fit)$table[, "median"])

medians_df <- medians_df %>%
  separate(group, into = c("received_stupp", "mgmt_status"), sep = "\\.") %>%
  mutate(received_stupp = sub(".*=", "", received_stupp))  

colnames(medians_df) <- c("Received Stupps?", "MGMT Status", "Median Survival (Months)")

medians_df %>% gt()
```

We see that Stupps + Methylated Status = longest median survival time. Kruskal-Wallis test to test for significance.

```{r}
library(dplyr)

df_stupps <- df %>% filter(stupps_mgmt %in% c("no.M", "yes.M", "no.UM", "yes.UM"))
group_by(df_stupps, stupps_mgmt) %>%
  summarise(
    count = n(),
    mean = mean(overall_survival, na.rm = TRUE),
    sd = sd(overall_survival, na.rm = TRUE),
    median = median(overall_survival, na.rm = TRUE),
    IQR = IQR(overall_survival, na.rm = TRUE)
  )

ggboxplot(df_stupps, x = "stupps_mgmt", y = "overall_survival", 
          color = "stupps_mgmt", palette = c("#00AFBB", "#E7B800", "#FC4E07", "forestgreen"),
          order = c("no.M", "yes.M", "no.UM", "yes.UM"),
          ylab = "Overall Survival", xlab = "Stupps/MGMT Combination")

kruskal.test(overall_survival ~ stupps_mgmt, data = df_stupps)
```

Statistically significant difference in groups.

### Initial Seizures and DVT/PE Data

```{r}
tbl1 <- table(df$seizures_presentation, df$seizures_later)
dimnames(tbl1) <- list(
  "Seizures at Presentation" = levels(factor(df$seizures_presentation)),
  "Seizures Later" = levels(factor(df$seizures_later))
)
tbl1
```
```{r}
tbl2 <- table(df$dvt_pe_presentation, df$dvt_pe_during)
dimnames(tbl2) <- list(
  "DVT/PE at Presentation" = levels(factor(df$dvt_pe_presentation)),
  "DVT/PE Later" = levels(factor(df$dvt_pe_during))
)
tbl2
```

```{r}
df_sei_dvt <- df %>% filter(seizures_presentation != "unclear" & seizures_later != "unclear") 

km <- survfit2(Surv(overall_survival, status == 1) ~ seizures_presentation, data = df_sei_dvt)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Patients With Seizures At Presentation"
  )

km <- survfit2(Surv(overall_survival, status == 1) ~ seizures_later, data = df_sei_dvt)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Patients With Seizures During Course"
  )

km <- survfit2(Surv(overall_survival, status == 1) ~ dvt_pe_presentation, data = df_sei_dvt)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Patients With DVT/PE at Presentation"
  )

km <- survfit2(Surv(overall_survival, status == 1) ~ dvt_pe_during, data = df_sei_dvt)
ggsurvfit(km) + 
  add_pvalue("annotation", size = 5) + 
  labs(
    x = "Time",
    title = "Survival of Patients With DVT/PE During Course"
  )
```

Looking at DVT/PE History

```{r}
table(df$dvt_pe_history)
```

